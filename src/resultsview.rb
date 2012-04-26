require 'ui_resultsview_base.rb'
require 'resultsmodel.rb'

class ResultsView < Qt::Widget
	slots 'fileActivated(const QModelIndex&)'
	slots :print, :showConfig

	attr_reader :settings

	def initialize( parent )
		super(parent)
		@ui = Ui_Resultsview_base.new
		@ui.setupUi(self)

		@model = ResultsModel.new
		@ui.treeView.setModel @model
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
		ca = it.job.caller
		ca.each do |c|
			puts c
			if c =~ /\A\(eval\):(\d+):in `block (\(\d+ levels\) |)in init'/
				system("kate", "-l", $1, $unikernel.unidir+"/config.rb")
			end
		end
	end
	
private
end
