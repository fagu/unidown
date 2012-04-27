
class NotificationsModel < Qt::AbstractListModel
	slots 'beforeclose(int)', 'afterclose()'
	def initialize(parent=nil)
		super(parent)
		Notification.alll.each do |n|
			connect(n, SIGNAL('beforeclose(int)'), self, SLOT('beforeclose(int)'))
			connect(n, SIGNAL('afterclose()'), self, SLOT('afterclose()'))
		end
	end
	def item(index)
		index.isValid ? Notification.alll[index.row] : nil
	end
	def rowCount(parent)
		return Notification.alll.size
	end
	def data(index, role)
		if !index.isValid
			return Qt::Variant.new
		else
			ip = item(index)
			if    role == Qt::DisplayRole && index.column == 0
				return Qt::Variant.new(ip.title)
			else
				return Qt::Variant.new
			end
		end
	end
	def headerData(section, orientation, role)
		return Qt::Variant.new
	end
	
	def beforeclose(r)
		beginRemoveRows(Qt::ModelIndex.new, r, r)
	end
	def afterclose
		endRemoveRows
	end
end
