class RegRequestsController < ApplicationController
  layout 'course'

  before_action :require_current_user
  before_action :find_course
  before_action :require_admin_or_prof, only: [:accept, :accept_all, :reject, :reject_all]

  # GET /courses/:course_id/reg_requests/new
  def new
    @reg_request = @course.reg_requests.new
  end

  # POST /courses/:course_id/reg_requests
  def create
    @reg_request = @course.reg_requests.new(reg_request_params)
    @reg_request.user = current_user

    if @reg_request.save
      @course.professors.each do |teacher|
        NotificationMailer.got_reg_request(teacher,
          @reg_request, root_url).deliver_later
      end

      redirect_to courses_path, notice: 'A registration request will be sent.'
    else
      render :new
    end
  end

  def accept
    @request = RegRequest.find(params[:id])
    errs = accept_help(@request)
    if errs
      redirect_back fallback_location: course_registrations_path(@course), alert: errs
    else
      redirect_back fallback_location: course_registrations_path(@course)
    end
  end

  def accept_all
    count = 0
    RegRequest.where(course_id: params[:course_id]).each do |req|
      errs = accept_help(req)
      if errs
        redirect_back fallback_location: course_registrations_path(@course), alert: errs
        return
      end
      count = count + 1
    end
    redirect_back fallback_location: course_registrations_path(@course),
                  notice: "#{pluralize(count, 'registration')} added"
  end

  def accept_help(request)
    begin
      reg = Registration.find_or_create_by(user: request.user,
                                           course: request.course,
                                           role: request.role,
                                           section: request.section)
      if reg
        reg.show_in_lists = (request[:role] == RegRequest::roles[:student])
        reg.dropped_date = nil
        reg.save!
        request.destroy
      end
      nil
    rescue Exception => err
      err.record.errors
    end
  end
  

  def reject
    RegRequest.find(params[:id]).delete
    redirect_back fallback_location: course_registrations_path(@course)
  end

  def reject_all
    RegRequest.where(course_id: params[:course_id]).delete_all # No dependents, so deletion is fine
    redirect_back fallback_location: course_registrations_path(@course)
  end

  private

  def reg_request_params
    ans = params[:reg_request].permit(:notes, :role, :section)
    ans[:section] = Section.find_by(crn: ans[:section].to_i)
    ans
  end
end
