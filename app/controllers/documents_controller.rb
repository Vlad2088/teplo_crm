class DocumentsController < ApplicationController
  before_action :set_order
  before_action :set_document, only: %i[ destroy ]

  # POST /orders/:order_id/documents
  def create
    @document = @order.documents.build(document_params)

    respond_to do |format|
      if @document.save
        format.html { redirect_to @order, notice: "Документ добавлен." }
        format.json { render :show, status: :created, location: @order }
      else
        format.html { redirect_to @order, alert: @document.errors.full_messages.to_sentence }
        format.json { render json: @document.errors, status: :unprocessable_content }
      end
    end
  end

  # GET /orders/:order_id/documents/:id/pdf — печатная форма
  def pdf
    document = @order.documents.find(params.expect(:id))
    pdf_body = Pdf::DocumentsService.new(document).render

    send_data pdf_body,
              filename: "#{document.doc_type}_#{document.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  rescue ActiveRecord::RecordNotFound
    redirect_to @order, alert: "Документ не найден."
  end

  # DELETE /orders/:order_id/documents/:id
  def destroy
    @document.destroy!
    respond_to do |format|
      format.html { redirect_to @order, notice: "Документ удалён.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

    def set_order
      @order = Order.find(params.expect(:order_id))
    end

    def set_document
      @document = @order.documents.find(params.expect(:id))
    end

    def document_params
      params.expect(document: [ :doc_type, :title, :description, :document_date ])
    end
end
