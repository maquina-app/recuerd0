class Memories::PreviewsController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace

  def create
    @content = params[:content].to_s
    render layout: false
  end
end
