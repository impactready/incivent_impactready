class MeasurementsController < ApplicationController

  def index
    @measurements = current_user.relevant_measurements(params[:search]).default_order
  end

  def new
    @account = current_user.account
    @measurement = current_user.measurements.new
  end

  def show
    @account = current_user.account
    deny_access_wrong_account unless @measurement = @account.account_measurements.measurements_from_groups_joined_by(current_user).find(params[:id])
  end

  def edit
    if (current_user.master_user? && current_user.account == Measurement.find(params[:id]).group.account ) || current_user.measurements.find(params[:id])
      @account = current_user.account
      @measurement = @account.account_measurements.find(params[:id])
    else
      deny_access_wrong_account
    end
  end

  def create
    @account = current_user.account
    @measurement = current_user.measurements.build(params[:measurement])
    group = @measurement.group
    if @measurement.save
      @measurement.group.users.each do |user|
        group.updates_add_create('measurement', @measurement)
        begin
          Notification.notify_measurement(user, group, measurement_url(@measurement)).deliver_now
        rescue Exception => e
          logger.error "Unable to deliver the update email: #{e.message}"
        end
      end
      flash[:success] = 'Indicator update created!'
      mobile_device? ? redirect_to(tasks_path) : redirect_to(measurements_path)
    else
      flash[:error] = 'The indicator update was not successfully created.'
      render 'new'
    end
  end

  def update
    @account = current_user.account
    @measurement = @account.account_measurements.measurements_from_groups_joined_by(current_user).find(params[:id])
    group = @measurement.group
    if @measurement.update_attributes(params[:measurement])
      group.updates_add_archive('measurement', @measurement) if @measurement.archive == true
      flash[:success] = 'Indicator update updated.'
      redirect_to measurements_path
    else
      flash[:error] = 'There were problems editing the indicator update.'
      render 'edit'
    end
  end

  def destroy
    account = current_user.account
    measurement = account.account_measurements.find(params[:id])
    group = measurement.group
    if measurement.destroy
      group.updates_add_delete('measurement', measurement)
      flash[:success] = 'Indicator update removed.'
      redirect_to measurements_path
    end
  end

  def sort_index
    @measurements = current_user.relevant_measurements(params[:search]).order(params[:sort])

    respond_to do |format|
      format.js
    end
  end

end
