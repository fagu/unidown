
class String
	def is_digit?
		return "0" <= self && self <= "9"
	end
end

class ResultsItem
	def initialize(name,path,parent,row)
		@name = name
		@path = path
		@parent = parent
		@row = row
		@ch = []
		@chmap = {}
		@icon = Qt::FileIconProvider.new.icon(Qt::FileInfo.new(@path))
	end
	def name
		@name
	end
	def path
		@path
	end
	def icon
		@icon
	end
	def parent
		@parent
	end
	def row
		@row
	end
	def childByIndex(i)
		@ch[i]
	end
	def childByName(n)
		if !@chmap[n]
			@ch.push ResultsItem.new(n,path+"/"+n,self,@ch.size)
			@chmap[n] = @ch.last
		end
		return @chmap[n]
	end
	def childCount
		@ch.size
	end
	def cmp(a,b)
		i, j = 0, 0
		while i < a.length && j < b.length
			if a[i].is_digit?
				if b[j].is_digit?
					is, js = i, j
					is += 1 while is < a.length && a[is].is_digit?
					js += 1 while js < b.length && b[js].is_digit?
					n1 = a[i,is-1]
					n2 = b[j,js-1]
					if (n1.to_i <=> n2.to_i) != 0
						return n1.to_i <=> n2.to_i
					elsif (n1 <=> n2) != 0
						return n1 <=> n2
					end
					i = is
					j = js
				else
					return -1
				end
			else
				if b[i].is_digit?
					return +1
				else
					if (a[i] <=> b[j]) != 0
						return a[i] <=> b[i]
					end
					i += 1
					j += 1
				end
			end
		end
		if i < b.length
			return -1
		elsif i < a.length
			return +1
		else
			return 0
		end
	end
	def sort
		@ch.each do |c|
			c.sort
		end
		@ch.sort!{|a,b|cmp(a.name,b.name)}
	end
end

class ResultsModel < Qt::AbstractItemModel
	def initialize(parent=nil)
		super(parent)
		@root = ResultsItem.new("",$unikernel.unidir,nil,0)
		SaveJob.savedfiles.each do |f,|
			li = f.split("/")
			it = @root
			li.each do |l|
				it = it.childByName(l)
			end
		end
		@root.sort
	end
	def item(index)
		index.isValid ? index.internalPointer : @root
	end
	def index(row, column, parent)
		if !hasIndex(row, column, parent)
			return Qt::ModelIndex.new
		end
		pait = parent.isValid ? parent.internalPointer : @root
		chit = pait.childByIndex(row)
		return createIndex(row, column, chit)
	end
	def parent(index)
		return Qt::ModelIndex.new if !index.isValid
		chit = index.internalPointer
		pait = chit.parent
		return pait == @root ? Qt::ModelIndex.new : createIndex(pait.row, 0, pait)
	end
	def rowCount(parent)
		pait = parent.isValid ? parent.internalPointer : @root
		return pait.childCount
	end
	def columnCount(parent)
		return rowCount(parent) ? 2 : 0
	end
	def data(index, role)
		if !index.isValid
			return Qt::Variant.new
		else
			ip = index.internalPointer
			if    role == Qt::DisplayRole && index.column == 0
				return Qt::Variant.new(ip.name)
			elsif role == Qt::DisplayRole && index.column == 1
				return Qt::Variant.new(ip.childCount)
# 			elsif role == Qt::ToolTipRole
# 				return Qt::Variant.new("bla")
# 			elsif role == Qt::CheckStateRole
# 				return Qt::Variant.fromValue(Qt::PartiallyChecked)
			elsif role == Qt::DecorationRole && index.column == 0
				return Qt::Variant.fromValue(ip.icon)
			else
				return Qt::Variant.new
			end
		end
	end
	def headerData(section, orientation, role)
		if (orientation == Qt::Horizontal && role == Qt::DisplayRole)
			return Qt::Variant.new(["Text", "Anzahl direkter Kinder"][section])
		else
			return Qt::Variant.new
		end
	end
end
