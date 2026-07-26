class CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: %i[edit update destroy]

  def index
    load_categories
  end

  def new
    @category = current_user.categories.new(icon_name: Category::DEFAULT_ICON)
  end

  def create
    @category = current_user.categories.new(category_params)

    if @category.save
      redirect_to categories_path,
        notice: t("category_management.create.success", name: @category.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path,
        notice: t("category_management.update.success", name: @category.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    category_name = @category.name
    sentence_count = @category.sentences.count
    @category.destroy!

    redirect_to categories_path,
      notice: t("category_management.destroy.success", name: category_name, count: sentence_count)
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey
    load_categories
    flash.now[:alert] = t("category_management.destroy.failure", name: @category.name)
    render :index, status: :unprocessable_entity
  end

  private

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def load_categories
    @categories = current_user.categories.includes(:sentences).order(:name)
  end

  def category_params
    params.require(:category).permit(:name, :icon_name)
  end
end
