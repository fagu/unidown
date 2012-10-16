require 'resultsview.rb'
require 'notificationsview.rb'

class Unidown < KDE::XmlGuiWindow
	slots 'systrayActivated(QSystemTrayIcon::ActivationReason)', :reload
	def initialize()
		super()

		$unikernel = UnidownKernel.new
		
		setAcceptDrops(true)

		spl = Qt::TabWidget.new(self)
		@notificationsview = NotificationsView.new
		spl.addTab @notificationsview, "Nachrichten"
		@resultsview = ResultsView.new
		spl.addTab @resultsview, "Ergebnisse"

		setCentralWidget(spl)

		setupActions
		
		setupTrayIcon

		setupGUI(ToolBar | Keys | Save | Create, "/usr/local/share/apps/unidown/unidownui.rc")
		
		statusBar.hide
		@timer = Qt::Timer.new(self)
		@timer.setSingleShot(true)
		@timer.setInterval(1000*60*60)
		connect(@timer, SIGNAL("timeout()"), self, SLOT(:reload))
		reload
		
		show
		
		@notificationsview.ui.list.focus = Qt::ActiveWindowFocusReason
		
		@no = KDE::Notification.new("blub")
# 		@no.setFlags(@no.flags)
		@no.setText("fdsaf")
		@no.setTitle("fdsafds")
# 		@no.setActions(["fdsaf"])
		@no.sendEvent
		@no.ref
# 		KDE::Notification::event("blub", "fdsa", "fdfdsad", Qt::Pixmap.new, self, KDE::Notification::Persistent)
	end
	
	def systrayActivated(r)
# 		if r == Qt::SystemTrayIcon::Trigger
# 			setVisible(!visible)
# 			@trayIcon.showMessage("Titel", "VIel Spam\nfdaf")
# 		end
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
		action = KDE::Action.new(i18n("Aktualisieren"), self)
		action.setShortcut(KDE::Shortcut.new(Qt::Key_F5))
		action.setIcon(Qt::Icon.fromTheme("view-refresh"))
		actionCollection.addAction("reload", action)
		connect(action, SIGNAL('triggered(bool)'), self, SLOT(:reload))
	end
	
	def setupTrayIcon
		@trayIcon = KDE::SystemTrayIcon.new(self)
# 		@trayIcon.setIcon(Qt::Icon.fromTheme("unidown"))
		@trayIcon.setIcon(KDE::Icon.new("unidown"))
		@trayIcon.show
		connect(@trayIcon, SIGNAL('activated(QSystemTrayIcon::ActivationReason)'), self, SLOT('systrayActivated(QSystemTrayIcon::ActivationReason)'))
	end
	
	def reload
		@timer.stop
		Notification.clear
		Job.clear
		SaveJob.clear
		puts "reload..."
		$unikernel = UnidownKernel.new
		Dir.chdir $unikernel.unidir do
			$unikernel.init
			$unikernel.download
			$unikernel.findjobs
			$unikernel.runjobs
			$unikernel.finalize
		end
		puts "finished!"
		@resultsview.reload
		@notificationsview.reload
		if Notification.alll.empty?
			@trayIcon.setIcon(KDE::Icon.new("unidown"))
		else
			@trayIcon.setIcon(KDE::Icon.new("unidownnotify"))
		end
		@timer.start
	end
end
