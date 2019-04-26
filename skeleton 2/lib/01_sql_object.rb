#require 'ostruct'
require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns unless @columns.nil?
    
    @columns = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
    @columns.first.map{|column| column.parameterize.underscore.to_sym} 
  end

  def self.finalize!
    @columns ||= self.columns
    
    @columns.each do |column_name|
      define_method("#{column_name}") do
        attributes[column_name]
      end

      define_method("#{column_name}=") do |value|
        attributes[column_name] = value
      end
    end
  end

  def self.table_name=(table_name)
    
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.to_s.tableize
  end

  def self.all
    rows = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL

    parse_all(rows)
  end

  def self.parse_all(results)
    results.map{|result| self.new(result)}
  end

  def self.find(id)
    self.all.each {|ele| return ele if ele.id == id}
    nil
  end

  def initialize(params = {})
    columns = self.class.columns
    self.class.finalize!

    params.keys.each do |param|
      raise ("unknown attribute '#{param.to_sym}'") unless columns.include?(param.to_sym)
      self.send("#{param.to_sym}=", params[param])
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    @attributes.values
  end

  def insert
   columns = self.class.columns.drop(1)
   col_names = columns.map(&:to_s).join(", ")
   question_marks = (["?"] * columns.count).join(", ")



    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns
      .map { |attr| "#{attr} = ?" }.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        #{self.class.table_name}.id = ?
    SQL
  end

  def save
    if self.id.nil?
      insert
    else
      update
    end
  end
end
