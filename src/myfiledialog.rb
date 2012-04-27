require 'ui_filedialogview_base.rb'

class MyFileDialog < KDE::Dialog
	slots 'changed(int)', 'changed(const QString&)', 'changed(bool)', :save
	def initialize(parent, loc, file)
		super(parent)
		@loc = loc
		@mainwidget = Qt::Widget.new(self)
		@ui = Ui_Filedialogview_base.new
		@ui.setupUi(@mainwidget)
		setCaption("Heruntergeladene Datei");
		setButtons(KDE::Dialog::Ok | KDE::Dialog::Cancel);
		setModal(true)
		setMinimumWidth(800)
		@ui.location.setText("<b>#{loc.destdir} (#{loc.url})</b>")
		@ui.pattern.setText(Regexp.escape(file))
		@ui.istitle.setChecked(true)
		@ui.save.setText(loc.destdir+"/")
		@ui.chapter_book.setText(loc.destdir)
		
		setMainWidget(@mainwidget)
		
		changed
		
		connect(@ui.pattern, SIGNAL('textChanged(const QString&)'), self, SLOT('changed(const QString&)'))
		connect(@ui.ignore, SIGNAL('stateChanged(int)'), self, SLOT('changed(int)'))
		connect(@ui.istitle, SIGNAL('stateChanged(int)'), self, SLOT('changed(int)'))
		connect(@ui.title, SIGNAL('textChanged(const QString&)'), self, SLOT('changed(const QString&)'))
		connect(@ui.save, SIGNAL('textChanged(const QString&)'), self, SLOT('changed(const QString&)'))
		connect(@ui.print, SIGNAL('stateChanged(int)'), self, SLOT('changed(int)'))
		connect(@ui.chapter, SIGNAL('toggled(bool)'), self, SLOT('changed(bool)'))
		connect(@ui.chapter_book, SIGNAL('textChanged(const QString&)'), self, SLOT('changed(const QString&)'))
		connect(@ui.chapter_sort, SIGNAL('textChanged(const QString&)'), self, SLOT('changed(const QString&)'))
		connect(@ui.chapter_title, SIGNAL('textChanged(const QString&)'), self, SLOT('changed(const QString&)'))
		connect(@ui.ruby, SIGNAL('textChanged(const QString&)'), self, SLOT('changed(const QString&)'))
		
		connect(self, SIGNAL('okClicked()'), self, SLOT('save()'));
		
		show
	end
	
	def changed(spam=nil)
		@ui.istitle.setEnabled !@ui.ignore.checked
		@ui.title.setEnabled !@ui.ignore.checked && @ui.istitle.checked
		@ui.issave.setEnabled !@ui.ignore.checked
		@ui.save.setEnabled !@ui.ignore.checked
		@ui.print.setEnabled !@ui.ignore.checked
		@ui.chapter.setEnabled !@ui.ignore.checked
		doer = "x"
		if !@ui.ignore.checked
			doer += " >> title(\"#{@ui.title.text}\")" if @ui.istitle.checked
			doer += " >> save(\"#{@ui.save.text}\")"
			doer += " >> pr" if @ui.print.checked
			doer += " >> ch([#{@ui.chapter_sort.text}], [#{@ui.chapter_title.text}], \"#{@ui.chapter_book.text}\")" if @ui.chapter.checked
		end
		ruby = "map('#{@ui.pattern.text}') {#{doer}}"
		
		@ui.ruby.setText ruby
	end
	
	def save
		l = @loc.callerline
		cf = File.join($unikernel.unidir,"config.rb")
		lines = IO.readlines(cf)
		erg = lines[0..(l-1)].join + "\t" + @ui.ruby.text + "\n" + lines[l..-1].join
		IO.write(cf, erg)
	end
end
