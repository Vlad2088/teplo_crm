class ExtendCompanySettings < ActiveRecord::Migration[8.1]
  def change
    # статус компании: individual_enterpreneur / legal_entity
    add_column :company_settings, :company_type, :integer, default: 0, null: false
    # гос. реквизиты и статистика (для ИП — ОГРНИП, для юрлица — ОГРН)
    add_column :company_settings, :ogrn, :string
    add_column :company_settings, :okpo, :string
    add_column :company_settings, :okved, :string
    # сокращённое наименование (юрлицо)
    add_column :company_settings, :short_name, :string
  end
end
