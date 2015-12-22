class StatementsController < ApplicationController
	before_filter :initialize_statement, except: [:index, :new, :create]

	def index		
		@statements = Statement.all
		@new_statement = Statement.new
	end

	def create
		@statement = Statement.create statement_params
		redirect_to(@statement)
	end

	def show
	end

	def destroy
		@statement.destroy
	end

	def update_data_points
		@statement.update_data_points(data_point_params)
		render nothing: true
	end

	private 
	def initialize_statement
		@statement = Statement.find_by_id params[:id]
		unless @statement 
			@statements = Statement.all
			@new_statement = Statement.new
			render("index")
		end
	end

	def statement_params
		params.require(:statement).permit(:name, :data_points)
	end

	def data_point_params
		params.require(:data_points)
	end
end
