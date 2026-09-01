class CreateCompanySettings < ActiveRecord::Migration[8.1]
  def change
    create_table :company_settings do |t|
      t.string :name, null: false
      t.string :inn
      t.string :kpp
      t.string :address
      t.string :phone
      t.string :email
      t.string :bank_name
      t.string :bank_bik
      t.string :bank_account
      t.string :bank_corr_account
      t.string :director_name
      t.string :position_title, default: "Индивидуальный предприниматель"

      t.timestamps
    end
  end
end
