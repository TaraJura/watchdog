class ApplicationController < ActionController::Base
  before_action :set_locale

  def set_locale_manually
    locale = params[:locale]
    if I18n.available_locales.map(&:to_s).include?(locale)
      session[:locale] = locale
      redirect_back(fallback_location: root_path)
    else
      redirect_to root_path
    end
  end

  private

  def set_locale
    I18n.locale = extract_locale || I18n.default_locale
    store_locale_in_session
  end

  def extract_locale
    # Priority: params > session > browser > default
    locale_from_params || locale_from_session || locale_from_headers
  end

  def locale_from_params
    parsed_locale = params[:locale]
    I18n.available_locales.map(&:to_s).include?(parsed_locale) ? parsed_locale : nil
  end

  def locale_from_session
    parsed_locale = session[:locale]
    I18n.available_locales.map(&:to_s).include?(parsed_locale) ? parsed_locale : nil
  end

  def locale_from_headers
    return nil unless request.env['HTTP_ACCEPT_LANGUAGE']

    accepted = request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first
    I18n.available_locales.map(&:to_s).include?(accepted) ? accepted : nil
  end

  def store_locale_in_session
    session[:locale] = I18n.locale.to_s
  end

  def default_url_options
    { locale: I18n.locale }
  end
end
