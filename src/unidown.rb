require 'resultsview.rb'

class Unidown < KDE::XmlGuiWindow
# Default Constructor
	def initialize()
		super()
		setAcceptDrops(true)

		@view = ResultsView.new(self)

		setCentralWidget(@view)

		setupActions

		setupGUI(ToolBar | Keys | Save | Create, "/usr/local/share/apps/unidown/unidownui.rc")
		
		statusBar.hide
	end

private
	def fileNew()
		puts Qt::FileDialog.getExistingDirectory
	end
	
private
	def setupActions()
# 		KDE::StandardAction.openNew(self, SLOT(:fileNew), actionCollection)
		KDE::StandardAction.quit($kapp, SLOT(:closeAllWindows), actionCollection)
		KDE::StandardAction.print(@view, SLOT(:print), actionCollection)
		action = KDE::Action.new(i18n("Konfiguration anzeigen"), self)
		action.setShortcut(KDE::Shortcut.new(Qt::CTRL + Qt::Key_K))
		actionCollection.addAction("file_config", action)
		connect(action, SIGNAL('triggered(bool)'), @view, SLOT(:showConfig))
# 		KDE::StandardAction.preferences(self, SLOT(:optionsPreferences), actionCollection)
		# custom menu and menu item - the slot is in the class ${APP_NAME}View
# 		custom = KDE::Action.new(KDE::Icon.new("colorize"), i18n("Swi&tch Colors"), self)
# 		actionCollection.addAction( "switch_action", custom )
# 		connect(custom, SIGNAL('triggered(bool)'), @view, SLOT(:switchColors))
	end

end
