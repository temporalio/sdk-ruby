# frozen_string_literal: true

require 'objspace'

module GCUtils
  class << self
    # Find one path from any GC root to the object with target_id.
    #
    # @return [Array<Object>, String] First value is array of path objects, second is root category.
    def find_retaining_path_to(target_id, max_depth: 12, max_visits: 250_000, category_whitelist: nil)
      roots = ObjectSpace.reachable_objects_from_root # {category_sym => [objs]}
      queue   = []
      seen    = {}
      parent  = {}    # child_id -> parent_id
      root_of = {}    # obj_id   -> root_category

      roots.each do |category, objs|
        next if category_whitelist && !category_whitelist.include?(category)

        objs.each do |o|
          id = o.__id__
          next if seen[id]

          seen[id] = true
          parent[id] = nil
          root_of[id] = category
          queue << o
        end
      end

      visits = 0
      depth  = 0
      level_remaining = queue.length
      next_level = 0

      found_leaf = nil

      while !queue.empty? && visits < max_visits && depth <= max_depth
        cur = queue.shift
        level_remaining -= 1
        visits += 1

        cid = cur.__id__
        if cid == target_id
          found_leaf = cid
          break
        end

        children = begin
          ObjectSpace.reachable_objects_from(cur)
        rescue StandardError
          nil
        end

        children&.each do |child|
          chid = child.__id__
          next if seen[chid]

          seen[chid] = true
          parent[chid] = cid
          root_of[chid] ||= root_of[cid]
          queue << child
          next_level += 1
        end

        next unless level_remaining.zero?

        depth += 1
        level_remaining = next_level
        next_level = 0
      end

      return [[], ''] unless found_leaf

      # Reconstruct path
      ids = []
      i = found_leaf
      while i
        ids << i
        i = parent[i]
      end
      objs = ids.reverse.map do |id|
        ObjectSpace._id2ref(id)
      rescue StandardError
        id
      end
      [objs, root_of[ids.first]]
    end

    # Return string of annotated path
    def annotated_path(path, root_category:)
      lines = []
      lines << "Retaining path (len=#{path.length}) from ROOT[:#{root_category}] to target:"
      return lines.join("\n") if path.empty?

      # First is the root
      lines << "  ROOT[:#{root_category}] #{describe_obj(path.first)}"
      # Then edges with labels
      (0...(path.length - 1)).each do |i|
        parent = path[i]
        child  = path[i + 1]
        labels = edge_labels(parent, child)
        labels.each_with_index do |lab, j|
          arrow = (j.zero? ? '    └─' : '      •')
          lines << "#{arrow} via #{lab} → #{describe_obj(child)}"
        end
      end
      lines.join("\n")
    end

    private

    # Label HOW +parent+ holds a reference to +child+ (ivar name, constant, index, etc.).
    def edge_labels(parent, child)
      labels = []
      target = child

      # 1) Instance variables (works for Class/Module too – class ivars are ivars on the Class object)
      if parent.respond_to?(:instance_variables)
        parent.instance_variables.each do |ivar|
          labels << "@#{ivar.to_s.delete('@')}" if parent.instance_variable_get(ivar).equal?(target)
        rescue StandardError
          # Ignore
        end
      end

      # 2) Class variables on Module/Class
      if parent.is_a?(Module)
        parent.class_variables.each do |cvar|
          labels << cvar.to_s if parent.class_variable_get(cvar).equal?(target)
        rescue NameError
          # Ignore
        end
      end

      # 3) Constants on Module/Class (avoid triggering autoload)
      if parent.is_a?(Module)
        parent.constants(false).each do |c|
          next if parent.respond_to?(:autoload?) && parent.autoload?(c)

          if parent.const_defined?(c, false)
            v = parent.const_get(c, false)
            labels << "::#{c}" if v.equal?(target)
          end
        rescue NameError, LoadError
          # Ignore
        end
      end

      # 4) Array elements
      if parent.is_a?(Array)
        parent.each_with_index do |v, i|
          labels << "[#{i}]" if v.equal?(target)
        end
      end

      # 5) Hash entries (key or value)
      if parent.is_a?(Hash)
        parent.each do |k, v|
          labels << "{key #{k.inspect}}" if k.equal?(target)
          labels << "{value for #{k.inspect}}" if v.equal?(target)
        end
      end

      # 6) Struct members
      if parent.is_a?(Struct)
        parent.members.each do |m|
          labels << ".#{m}" if parent[m].equal?(target)
        rescue StandardError
          # Ignore
        end
      end

      # 7) Fallback for VM internals
      if labels.empty?
        begin
          labels << '(internal)' if parent.is_a?(ObjectSpace::InternalObjectWrapper)
        rescue StandardError
          # Ignore
        end
      end

      labels.empty? ? ['(unknown edge)'] : labels
    end

    def describe_obj(obj)
      cls = (obj.is_a?(Module) ? obj : obj.class)
      "#<#{cls} 0x#{obj.__id__.to_s(16)}>"
    rescue StandardError
      obj.inspect
    end
  end
end
