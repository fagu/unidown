require 'korundum4'
require 'unidown.rb'
require 'kernel.rb'

description = "Unidown"
version = "1"

about = KDE::AboutData.new("unidown", nil, KDE::ki18n("unidown"), version, KDE::ki18n(description),
                           KDE::AboutData::License_LGPL, KDE::ki18n("(C) 2012 Fabian Gundlach"), KDE::LocalizedString.new, nil, "%{EMAIL}" )
about.addAuthor( KDE::ki18n("Fabian Gundlach"), KDE::LocalizedString.new, "%{EMAIL}" )
about.setProgramIconName("unidown")
KDE::CmdLineArgs.init(ARGV, about)

options = KDE::CmdLineOptions.new
options.add("+[URL]", KDE::ki18n( "Document to open" ))
KDE::CmdLineArgs.addCmdLineOptions(options)
app = KDE::Application.new
$mainwindow = Unidown.new
app.exec
