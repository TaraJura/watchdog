class PushSubscriptionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]

  def create
    subscription = find_or_create_subscription

    if subscription.persisted?
      render json: { success: true }, status: :created
    else
      render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing => e
    render json: { errors: [e.message] }, status: :bad_request
  end

  def vapid_public_key
    public_key = ENV.fetch('VAPID_PUBLIC_KEY', nil)

    if public_key.present?
      render json: { publicKey: public_key }
    else
      render json: { error: 'VAPID public key not configured' }, status: :internal_server_error
    end
  end

  private

  def find_or_create_subscription
    PushSubscription.find_or_create_by(endpoint: subscription_params[:endpoint]) do |subscription|
      subscription.p256dh = subscription_params[:keys][:p256dh]
      subscription.auth = subscription_params[:keys][:auth]
    end
  end

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
  end
end
