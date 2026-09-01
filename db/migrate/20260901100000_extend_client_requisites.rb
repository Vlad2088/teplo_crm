class ExtendClientRequisites < ActiveRecord::Migration[8.1]
  def change
    # физлицо: персональные и паспортные данные
    add_column :clients, :gender, :integer
    add_column :clients, :birth_date, :date
    add_column :clients, :birth_place, :string
    add_column :clients, :passport_series, :string
    add_column :clients, :passport_number, :string
    add_column :clients, :passport_issued_on, :date
    add_column :clients, :passport_department_code, :string
    add_column :clients, :passport_issued_by, :string
    add_column :clients, :registration_address, :text

    # ИП / юрлицо: гос. реквизиты и статистика
    add_column :clients, :ogrn, :string
    add_column :clients, :okpo, :string
    add_column :clients, :okved, :string
    add_column :clients, :short_name, :string

    # банк (ИП / юрлицо)
    add_column :clients, :bank_name, :string
    add_column :clients, :bank_bik, :string
    add_column :clients, :bank_account, :string
    add_column :clients, :bank_corr_account, :string

    # юрлицо: руководитель
    add_column :clients, :director_position, :string
    add_column :clients, :director_name, :string
  end
end
