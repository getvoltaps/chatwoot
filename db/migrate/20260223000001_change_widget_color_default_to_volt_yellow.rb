class ChangeWidgetColorDefaultToVoltYellow < ActiveRecord::Migration[7.0]
  def change
    change_column_default :channel_web_widgets, :widget_color, from: '#1f93ff', to: '#E8C840'
    change_column_default :labels, :color, from: '#1f93ff', to: '#E8C840'
  end
end
