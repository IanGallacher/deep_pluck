require 'deep_pluck/preloaded_model'
require 'deep_pluck/data_combiner'
module DeepPluck
  class Model
    # ----------------------------------------------------------------
    # ● Initialize
    # ----------------------------------------------------------------
    def initialize(relation, parent_association_key = nil, parent_model = nil, preloaded_model: nil)
      @relation = relation
      @preloaded_model = preloaded_model
      @parent_association_key = parent_association_key
      @parent_model = parent_model
      @need_columns = (preloaded_model ? preloaded_model.need_columns : [])
      @associations = {}
    end

    # ----------------------------------------------------------------
    # ● Reader
    # ----------------------------------------------------------------
    def get_reflect(association_key)
      @relation.klass.reflect_on_association(association_key.to_sym) || # add to_sym since rails 3 only support symbol
        fail(ActiveRecord::ConfigurationError, "ActiveRecord::ConfigurationError: Association named \
          '#{association_key}' was not found on #{@relation.klass.name}; perhaps you misspelled it?"
        )
    end

    def with_conditions(reflect, relation)
      options = reflect.options
      relation = relation.instance_exec(&reflect.scope) if reflect.respond_to?(:scope) and reflect.scope
      relation = relation.where(options[:conditions]) if options[:conditions]
      return relation
    end

    def get_join_table(reflect)
      options = reflect.options
      return options[:through] if options[:through]
      return (options[:join_table] || reflect.send(:derive_join_table)) if reflect.macro == :has_and_belongs_to_many
      return nil
    end

    def get_primary_key(reflect)
      return (reflect.belongs_to? ? reflect.klass : reflect.active_record).primary_key
    end

    def get_foreign_key(reflect, reverse: false, with_table_name: false)
      if reverse and (table_name = get_join_table(reflect)) # reverse = parent
        key = reflect.chain.last.foreign_key
      else
        key = (reflect.belongs_to? == reverse ? get_primary_key(reflect) : reflect.foreign_key)
        table_name = (reverse ? reflect.klass : reflect.active_record).table_name
      end
      return "#{table_name}.#{key}" if with_table_name
      return key.to_s # key may be symbol if specify foreign_key in association options
    end

    # ----------------------------------------------------------------
    # ● Contruction OPs
    # ----------------------------------------------------------------

    private

    def add_need_column(column)
      @need_columns << column.to_s
    end

    def add_association(hash)
      hash.each do |key, value|
        model = (@associations[key] ||= Model.new(get_reflect(key).klass.where(''), key, self))
        model.add(value)
      end
    end

    public

    def add(args)
      return self if args == nil
      args = [args] if not args.is_a?(Array)
      args.each do |arg|
        case arg
        when Hash ; add_association(arg)
        else      ; add_need_column(arg)
        end
      end
      return self
    end

    # ----------------------------------------------------------------
    # ● Load
    # ----------------------------------------------------------------
    private

    def do_query(parent, reflect, relation)
      parent_key = get_foreign_key(reflect)
      relation_key = get_foreign_key(reflect, reverse: true, with_table_name: true)
      ids = parent.map{|s| s[parent_key]}
      ids.uniq!
      ids.compact!
      relation = with_conditions(reflect, relation)
      query = { relation_key => ids }
      query[reflect.type] = reflect.active_record.to_s if reflect.type
      return relation.joins(get_join_table(reflect)).where(query)
    end

    def set_includes_data(parent, column_name, model)
      reflect = get_reflect(column_name)
      reverse = !reflect.belongs_to?
      foreign_key = get_foreign_key(reflect, reverse: reverse)
      primary_key = get_primary_key(reflect)
      children = model.load_data{|relation| do_query(parent, reflect, relation) }
      # reverse = false: Child.where(:id => parent.pluck(:child_id))
      # reverse = true : Child.where(:parent_id => parent.pluck(:id))
      return DataCombiner.combine_data(
        parent,
        children,
        primary_key,
        column_name,
        foreign_key,
        reverse,
        reflect.collection?,
      )
    end

    def get_query_columns
      if @parent_model
        parent_reflect = @parent_model.get_reflect(@parent_association_key)
        prev_need_columns = @parent_model.get_foreign_key(parent_reflect, reverse: true, with_table_name: true)
      end
      next_need_columns = @associations.map{|key, _| get_foreign_key(get_reflect(key), with_table_name: true) }.uniq
      return [*prev_need_columns, *next_need_columns, *@need_columns].uniq(&Helper::TO_KEY_PROC)
    end

    public

    def load_data
      columns = get_query_columns
      key_columns = columns.map(&Helper::TO_KEY_PROC)
      @relation = yield(@relation) if block_given?
      @data = @preloaded_model ? [@preloaded_model.get_hash_data(key_columns)] : @relation.pluck_all(*columns)
      if @data.size != 0
        # for delete_extra_column_data!
        @extra_columns = key_columns - @need_columns.map(&Helper::TO_KEY_PROC)
        @associations.each do |key, model|
          set_includes_data(@data, key, model)
        end
      end
      return @data
    end

    def load_all
      load_data
      delete_extra_column_data!
      return @data
    end

    def delete_extra_column_data!
      return if @data.blank?
      @data.each{|s| s.except!(*@extra_columns) }
      @associations.each{|_, model| model.delete_extra_column_data! }
    end

    # ----------------------------------------------------------------
    # ● Helper methods
    # ----------------------------------------------------------------
    module Helper
      TO_KEY_PROC = proc{|s| Helper.column_to_key(s) }
      def self.column_to_key(key) # user_achievements.user_id => user_id
        key = key[/(\w+)[^\w]*\z/]
        key.gsub!(/[^\w]+/, '')
        return key
      end
    end
  end
end
