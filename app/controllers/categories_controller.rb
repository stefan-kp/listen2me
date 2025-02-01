class CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: [:edit, :update, :destroy]

  def index
    @categories = current_user.categories.order(:name)
  end

  def new
    @category = current_user.categories.new
  end

  def create
    @category = current_user.categories.new(category_params)

    if @category.save
      redirect_to categories_path, notice: t('.category_created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: t('.category_updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.sentences.any?
      @categories = current_user.categories.order(:name)
      flash.now[:alert] = t('.cannot_delete_with_sentences', count: @category.sentences.count)
      render :index, status: :unprocessable_entity
    else
      @category.destroy
      redirect_to categories_path, notice: t('.category_deleted')
    end
  end

  private

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :icon_name)
  end
end 