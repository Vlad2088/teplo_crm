class CompanySettingsController < ApplicationController
  before_action :set_company_setting

  # GET /company_setting
  def show
    redirect_to edit_company_setting_path
  end

  # GET /company_setting/edit
  def edit
  end

  # PATCH/PUT /company_setting
  def update
    respond_to do |format|
      if @company_setting.update(company_setting_params)
        format.html { redirect_to edit_company_setting_path, notice: "Реквизиты компании сохранены." }
        format.json { render :show, status: :ok, location: @company_setting }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @company_setting.errors, status: :unprocessable_content }
      end
    end
  end

  private

    def set_company_setting
      @company_setting = CompanySetting.current
    end

    def company_setting_params
      params.expect(company_setting: [ :name, :inn, :kpp, :address, :phone, :email,
                                       :bank_name, :bank_bik, :bank_account, :bank_corr_account,
                                       :director_name, :position_title, :company_type, :ogrn, :okpo, :okved, :short_name ])
    end
end
