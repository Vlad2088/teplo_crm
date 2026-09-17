class OrganizationsController < ApplicationController
  before_action :set_organization, only: %i[ show edit update destroy ]

  # GET /organizations
  def index
    @organizations = Organization.order(:id)
  end

  # GET /organizations/1
  def show
    redirect_to edit_organization_path(@organization)
  end

  # GET /organizations/new
  def new
    @organization = Organization.new
  end

  # GET /organizations/1/edit
  def edit
  end

  # POST /organizations
  def create
    @organization = Organization.new(organization_params)

    if @organization.save
      redirect_to organizations_path, notice: "Организация добавлена."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /organizations/1
  def update
    if @organization.update(organization_params)
      redirect_to organizations_path, notice: "Реквизиты организации сохранены."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /organizations/1
  def destroy
    @organization.destroy!
    redirect_to organizations_path, notice: "Организация удалена.", status: :see_other
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to organizations_path, alert: "Нельзя удалить организацию: #{e.record.errors.full_messages.to_sentence}"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to organizations_path, alert: "Нельзя удалить организацию: за ней закреплены заказы."
  end

  private

    def set_organization
      @organization = Organization.find(params.expect(:id))
    end

    def organization_params
      params.expect(organization: [ :name, :inn, :kpp, :address, :phone, :email,
                                     :bank_name, :bank_bik, :bank_account, :bank_corr_account,
                                     :director_name, :position_title, :company_type, :ogrn, :okpo, :okved, :short_name ])
    end
end
