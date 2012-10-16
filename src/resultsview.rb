require 'ui_resultsview_base.rb'
require 'resultsmodel.rb'

class ResultsView < Qt::Widget
	slots 'fileActivated(const QModelIndex&)'
	slots :print

	def initialize(parent = nil)
		super(parent)
		@ui = Ui_Resultsview_base.new
		@ui.setupUi(self)
		reload
		@ui.treeView.header.setResizeMode 0, Qt::HeaderView::Stretch
		@ui.treeView.header.setResizeMode 1, Qt::HeaderView::ResizeToContents
		@ui.treeView.header.setResizeMode 2, Qt::HeaderView::ResizeToContents
		@ui.treeView.header.setStretchLastSection false
		
		connect(@ui.treeView, SIGNAL('doubleClicked(const QModelIndex&)'), self, SLOT('fileActivated(const QModelIndex&)'))
	end
	
	def fileActivated(index)
		it = @model.item(index)
		if it.childCount == 0
			Qt::DesktopServices::openUrl Qt::Url.new it.path
			puts "activated"
		end
	end
	
	def print
		return if !@ui.treeView.currentIndex.isValid
		it = @model.item(@ui.treeView.currentIndex)
		return if it.childCount != 0
		puts "print"
	end
	
	def showConfig
		return if !@ui.treeView.currentIndex.isValid
		it = @model.item(@ui.treeView.currentIndex)
		return if it.childCount != 0
		it.job.showconfig
	end
	
	def reload
		@model = ResultsModel.new
		@ui.treeView.setModel @model
	end
end
