require 'resultsview.rb'
require 'notificationsview.rb'

class Unidown < KDE::XmlGuiWindow
	slots 'systrayActivated(QSystemTrayIcon::ActivationReason)', :reloaddown, :reloadnodown, :reloadTray, :showConfig
	def initialize()
		super()

		$unikernel = UnidownKernel.new
		
		setAcceptDrops(true)

		@spl = Qt::TabWidget.new(self)
		@notificationsview = NotificationsView.new
		@spl.addTab @notificationsview, "Nachrichten"
		@resultsview = ResultsView.new
		@spl.addTab @resultsview, "Ergebnisse"

		setCentralWidget(@spl)
		
		setupTrayIcon
		connect(NotificationHandler.han, SIGNAL('closednotification()'), self, SLOT('reloadTray()'))

		setupActions
		
		setupGUI(ToolBar | Keys | Save | Create | StatusBar, "/usr/local/share/apps/unidown/unidownui.rc")
		
		@timer = Qt::Timer.new(self)
		@timer.setSingleShot(true)
		@timer.setInterval(1000*60*30)
		connect(@timer, SIGNAL("timeout()"), self, SLOT(:reloaddown))
		
# 		show
		reload
		
		@notificationsview.ui.list.focus = Qt::ActiveWindowFocusReason
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
		connect(action, SIGNAL('triggered(bool)'), self, SLOT(:showConfig))
		
		action = KDE::Action.new(i18n("Aktualisieren"), self)
		action.setShortcut(KDE::Shortcut.new(Qt::Key_F5))
		action.setIcon(Qt::Icon.fromTheme("view-refresh"))
		actionCollection.addAction("reload", action)
		@trayIcon.contextMenu.addAction(action)
		connect(action, SIGNAL('triggered(bool)'), self, SLOT(:reloaddown))
		
		action = KDE::Action.new(i18n("Aktualisieren (ohne Download)"), self)
		action.setShortcut(KDE::Shortcut.new(Qt::Key_F5+Qt::SHIFT))
		action.setIcon(Qt::Icon.fromTheme("view-refresh"))
		actionCollection.addAction("reload-nodownload", action)
		connect(action, SIGNAL('triggered(bool)'), self, SLOT(:reloadnodown))
	end
	
	def setupTrayIcon
		@trayIcon = KDE::StatusNotifierItem.new(self)
		@trayIcon.title = "Unizeug"
		@trayIcon.category = KDE::StatusNotifierItem::Communications
		@trayIcon.setIconByName("unidown")
		reloadTray
	end
	
	def reloaddown
		reload(true)
	end
	def reloadnodown
		reload(false)
	end
	def reload(down=true)
		@timer.stop
		Notification.clear
		Job.clear
		SaveJob.clear
		puts "reload..."
		start = Time.new
		$unikernel = UnidownKernel.new
		Dir.chdir $unikernel.unidir do
			$unikernel.init
			$unikernel.download if down
			$unikernel.findjobs
			$unikernel.runjobs
			$unikernel.finalize
		end
		puts "finished!"
		@resultsview.reload
		@notificationsview.reload
		reloadTray
		if !Notification.alll.empty?
			@trayIcon.showMessage("Unizeug", "Es gibt Neuigkeiten:\n"+Notification.alll.map{|x|x.title}.join("\n"), "unidown", 30000)
		end
		statusBar.removeItem(0) if statusBar.hasItem(0)
		statusBar.insertPermanentItem("Zuletzt aktualisiert #{Time.new.strftime 'am %d.%m.%Y um %H:%M:%S'} (Dauer #{'%.1f' % (Time.new-start)} Sekunden)",0)
		@timer.start
	end
	
	def reloadTray
		if Notification.alll.empty?
			@trayIcon.setIconByName("unidown")
			@trayIcon.status = KDE::StatusNotifierItem::Active
		else
			@trayIcon.setIconByName("unidownnotify")
			@trayIcon.status = KDE::StatusNotifierItem::Active
# 			@trayIcon.status = KDE::StatusNotifierItem::NeedsAttention
		end
	end
	
	def showConfig
		if @spl.currentIndex != 1
			system("kate", $unikernel.unidir+"/config.rb")
		else
			@resultsview.showConfig
		end
	end
end
