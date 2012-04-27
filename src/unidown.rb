require 'resultsview.rb'
require 'notificationsview.rb'

class Unidown < KDE::XmlGuiWindow
	def initialize()
		super()
		setAcceptDrops(true)

		spl = Qt::TabWidget.new(self)
		@notificationsview = NotificationsView.new
		spl.addTab @notificationsview, "Nachrichten"
		@resultsview = ResultsView.new
		spl.addTab @resultsview, "Ergebnisse"

		setCentralWidget(spl)

		setupActions

		setupGUI(ToolBar | Keys | Save | Create, "/usr/local/share/apps/unidown/unidownui.rc")
		
		statusBar.hide
	end

private
	def fileNew()
		puts Qt::FileDialog.getExistingDirectory
	end
	
	def setupActions()
		KDE::StandardAction.quit($kapp, SLOT(:closeAllWindows), actionCollection)
		KDE::StandardAction.print(@resultsview, SLOT(:print), actionCollection)
		action = KDE::Action.new(i18n("Konfiguration anzeigen"), self)
		action.setShortcut(KDE::Shortcut.new(Qt::CTRL + Qt::Key_K))
		actionCollection.addAction("file_config", action)
		connect(action, SIGNAL('triggered(bool)'), @resultsview, SLOT(:showConfig))
	end
end
