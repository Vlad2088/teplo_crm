class ClientsController < ApplicationController
  before_action :set_client, only: %i[ show edit update destroy ]

  # GET /clients or /clients.json
  def index
    @clients = Client.all
  end

  # GET /clients/1 or /clients/1.json
  def show
  end

  # GET /clients/new
  def new
    @client = Client.new
  end

  # GET /clients/1/edit
  def edit
  end

  # POST /clients or /clients.json
  def create
    @client = Client.new(client_params)

    respond_to do |format|
      if @client.save
        format.html { redirect_to @client, notice: "Client was successfully created." }
        format.json { render :show, status: :created, location: @client }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @client.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /clients/1 or /clients/1.json
  def update
    respond_to do |format|
      if @client.update(client_params)
        format.html { redirect_to @client, notice: "Client was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @client }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @client.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /clients/1 or /clients/1.json
  def destroy
    @client.destroy!

    respond_to do |format|
      format.html { redirect_to clients_path, notice: "Client was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_client
      @client = Client.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def client_params
      params.expect(client: [ :name, :phone, :email, :address, :client_type,
      :gender, :birth_date, :birth_place,
      :passport_series, :passport_number, :passport_issued_on,
      :passport_department_code, :passport_issued_by, :registration_address,
      :inn, :kpp, :ogrn, :okpo, :okved, :short_name,
      :bank_name, :bank_bik, :bank_account, :bank_corr_account,
      :director_position, :director_name ])
    end
end
