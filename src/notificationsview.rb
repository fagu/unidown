require 'ui_notificationsview_base.rb'
require 'notificationsmodel.rb'

class NotificationsView < Qt::Widget
	slots 'notificationActivated(const QModelIndex&, const QModelIndex&)'
	
	def initialize(parent = nil)
		super(parent)
		@ui = Ui_Notificationsview_base.new
		@ui.setupUi(self)
		notificationActivated(Qt::ModelIndex.new)
		
		@model = NotificationsModel.new
		@model.rowCount(Qt::ModelIndex.new)
		@ui.list.setModel @model
		connect(@ui.list.selectionModel, SIGNAL('currentChanged(const QModelIndex&, const QModelIndex&)'), self, SLOT('notificationActivated(const QModelIndex&, const QModelIndex&)'))
	end
	
	def notificationActivated(index, spam=nil)
		if !index.isValid
			@ui.question.hide
			@ui.buttonwidget.hide
		else
			@ui.question.show
			@ui.buttonwidget.show
			it = @model.item(index)
			@ui.question.setText "<b>"+it.title+"</b>"
			lay = @ui.buttonwidget.layout
			if lay
				i = lay.count-1
				while i >= 0
					b = lay.itemAt(i)
					lay.removeItem(b)
					b.widget.dispose
					b.dispose
					i -= 1
				end
				lay.dispose
			end
			
			lay = Qt::HBoxLayout.new
			@ui.buttonwidget.setLayout lay
			it.choices.each do |c|
				b = Qt::PushButton.new(c.name)
				connect(b, SIGNAL('clicked()'), c, SLOT('run()'))
				lay.addWidget b
			end
		end
	end
end
