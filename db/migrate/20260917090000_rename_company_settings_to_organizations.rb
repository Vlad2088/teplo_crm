class RenameCompanySettingsToOrganizations < ActiveRecord::Migration[8.1]
  def up
    rename_table :company_settings, :organizations

    # В чистой базе (прод) записи может не быть — создаём заглушку,
    # иначе нельзя привязать заказы и поставить NOT NULL.
    if select_value("SELECT COUNT(*) FROM organizations").to_i.zero?
      execute <<~SQL
        INSERT INTO organizations (name, company_type, created_at, updated_at)
        VALUES ('ИП — заполните реквизиты', 0, NOW(), NOW())
      SQL
    end

    # Каждый заказ привязывается к первой организации (решение: без флажка «по умолчанию»)
    add_reference :orders, :organization, foreign_key: true
    execute "UPDATE orders SET organization_id = (SELECT MIN(id) FROM organizations) WHERE organization_id IS NULL"
    change_column_null :orders, :organization_id, false

    # Признак «позиция списана со склада» (статусы заказов теперь управляют складом)
    add_column :order_items, :stock_withdrawn, :boolean, default: false, null: false

    # По новым правилам черновики (0 lead / 1 measurement / 2 estimate) и отменённые (9)
    # заказы склад не держат: удаляем их авторасходы и возвращаем ровно удалённую сумму.
    execute <<~SQL
      WITH doomed AS (
        DELETE FROM stock_movements sm
        WHERE sm.movement_type = 1
          AND sm.order_id IN (SELECT id FROM orders WHERE status IN (0, 1, 2, 9))
          AND EXISTS (
            SELECT 1 FROM order_items oi
            WHERE oi.order_id = sm.order_id
              AND oi.item_type = 'Product'
              AND oi.item_id = sm.product_id
              AND oi.quantity = sm.quantity_change
          )
        RETURNING sm.product_id, sm.quantity_change
      )
      UPDATE products p
      SET stock_quantity = p.stock_quantity + COALESCE((
        SELECT SUM(d.quantity_change) FROM doomed d WHERE d.product_id = p.id
      ), 0)
    SQL

    # Позиция считается списанной, если за ней стоит расход (после чистки черновиков —
    # только позиции «реальных» заказов)
    execute <<~SQL
      UPDATE order_items oi
      SET stock_withdrawn = TRUE
      WHERE oi.item_type = 'Product'
        AND EXISTS (
          SELECT 1 FROM stock_movements sm
          WHERE sm.order_id = oi.order_id
            AND sm.product_id = oi.item_id
            AND sm.movement_type = 1
            AND sm.quantity_change = oi.quantity
        )
    SQL
  end

  def down
    remove_column :order_items, :stock_withdrawn
    remove_reference :orders, :organization, foreign_key: true
    rename_table :organizations, :company_settings
    # Удалённые движения склада не восстанавливаются (down — аварийный путь)
  end
end
