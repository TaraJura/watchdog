module ApplicationHelper
  def language_toggle_button
    target_locale = I18n.locale == :en ? :cs : :en
    label = I18n.locale == :en ? t('language.switch_to_czech') : t('language.switch_to_english')

    link_to set_locale_path(locale: target_locale), class: "language-toggle" do
      "🌐 #{label}".html_safe
    end
  end
end
