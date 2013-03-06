class Dashboard::ArticlesController < Dashboard::BaseController
  skip_filter :require_logined, :only => :index

  def index
    if logined?
      @articles = current_user.articles.desc(:created_at).limit(25).skip(params[:skip]).status(params[:status]).includes(:category)

      append_title I18n.t('all_articles')
      append_title I18n.t(params[:status]) if params[:status].present?

      respond_to do |format|
        format.html
        format.js
      end
    else
      render :guest_index
    end
  end

  def category
    @category = current_user.categories.find_by :urlname => params[:category_id]
    @articles = current_user.articles.where(:category_id => @category).desc(:created_at).limit(25).skip(params[:skip]).status(params[:status]).includes(:category)

    append_title @category.name
    append_title I18n.t(params[:status]) if params[:status].present?

    respond_to do |format|
      format.html { render :index }
      format.js { render :index }
    end
  end

  def not_collected
    @articles = current_user.articles.where(:category_id => nil).desc(:created_at).limit(25).skip(params[:skip]).status(params[:status]).includes(:category)

    append_title t('not_collected')
    append_title I18n.t(params[:status]) if params[:status].present?

    respond_to do |format|
      format.html { render :index }
      format.js { render :index }
    end
  end

  def new
    @article = Article.new
    if params[:category_id]
      @article.category = current_user.categories.where(:urlname => params[:category_id]).first
    end
    append_title @article.title
    render :edit, :layout => false
  end

  def create
    @article = current_user.articles.new article_params
    if @article.save
      respond_to do |format|
        format.json { render :json => @article.as_json(:only => [:urlname, :title, :status, :token]).merge(:url => site_article_url(@article, :urlname => @article.urlname, :host => current_user.host)) }
      end
    else
      respond_to do |format|
        format.json { render :json => { :message => @article.errors.full_messages.join }, :status => 400 }
      end
    end
  end

  def edit
    @article = current_user.articles.find_by(:token => params[:id])
    append_title @article.title
    render :layout => false
  end

  def update
    @article = current_user.articles.find_by(:token => params[:id])
    if @article.update_attributes article_params
      respond_to do |format|
        format.json { render :json => @article.as_json(:only => [:urlname, :title, :status, :token]).merge(:url => site_article_url(@article, :urlname => @article.urlname, :host => current_user.host)) }
      end
    else
      respond_to do |format|
        format.json { render :json => { :message => @article.errors.full_messages.join }, :status => 400 }
      end
    end
  end

  def bulk
    @articles = current_user.articles.where(:token.in => params.require(:ids))

    case params[:type]
    when 'move'
      category = current_user.categories.where(:urlname => params[:category_id]).first
      @articles.update_all :category_id => category.try(:id)
    when 'publish'
      @articles.update_all :status => 'publish'
    when 'draft'
      @articles.update_all :status => 'draft'
    when 'trash'
      @articles.update_all :status => 'trash'
    when 'delete'
      @articles.trash.delete_all
    end

    respond_to do |format|
      format.json { render :json => @articles.includes(:category).as_json(:only => [:title, :urlname, :status, :token], :methods => [:category_name, :category_urlname]) }
    end
  end

  def empty_trash
    if params[:category_id]
      current_user.articles.where(:category_id => current_user.categories.find_by(:urlname => params[:category_id])).trash.delete_all
    elsif params[:not_collected]
      current_user.articles.where(:category_id => nil).trash.delete_all
    else
      current_user.articles.trash.delete_all
    end

    respond_to do |format|
      format.json { render :json => [] }
    end
  end

  private

  def article_params
    base_params = params.require(:article).permit(:title, :body, :urlname, :status)

    if params[:article][:category_id]
      base_params.merge!(:category => current_user.categories.where(:urlname => params[:article][:category_id]).first)
    end

    base_params
  end
end
