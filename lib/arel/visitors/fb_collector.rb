module Arel
  module Visitors
    class Fb < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_SelectStatement o, collector
        collector << "SELECT "
        collector = visit o.offset, collector if o.offset && !o.limit

        collector = o.cores.inject(collector) { |c,x|
          visit_Arel_Nodes_SelectCore(x, c)
        }

        unless o.orders.empty?
          collector << ORDER_BY
          len = o.orders.length - 1
          o.orders.each_with_index { |x, i|
            collector = visit(x, collector)
            collector << COMMA unless len == i
          }
        end

        if o.limit && o.offset
          collector = limit_with_rows o, collector
        elsif o.limit && !o.offset
          collector = visit o.limit, collector
        end

        collector = maybe_visit o.lock, collector
        collector
      end

      def visit_Arel_Nodes_SelectCore o, collector
        if o.set_quantifier
          collector = visit o.set_quantifier, collector
          collector << SPACE
        end

        unless o.projections.empty?
          len = o.projections.length - 1
          o.projections.each_with_index do |x, i|
            collector = visit(x, collector)
            collector << COMMA unless len == i
          end
        end

        if o.source && !o.source.empty?
          collector << " FROM "
          collector = visit o.source, collector
        end

        unless o.wheres.empty?
          collector << WHERE
          len = o.wheres.length - 1
          o.wheres.each_with_index do |x, i|
            collector = visit(x, collector)
            collector << AND unless len == i
          end
        end

        unless o.groups.empty?
          collector << GROUP_BY
          len = o.groups.length - 1
          o.groups.each_with_index do |x, i|
            collector = visit(x, collector)
            collector << COMMA unless len == i
          end
        end

        collector = maybe_visit o.having, collector
        collector
      end

      def visit_Arel_Nodes_Limit o, collector
        collector << " ROWS "
        visit o.expr, collector
      end

      def visit_Arel_Nodes_Offset o, collector
        collector << " SKIP "
        visit o.expr, collector
        collector << SPACE
      end

      # Firebird helper
      def limit_with_rows o, collector
        collector << " ROWS "
        visit o.offset.expr + 1, collector
        collector << " TO "
        visit o.offset.expr + o.limit.expr.expr, collector
      end
    end
  end
end

Arel::Visitors::VISITORS['fb'] = Arel::Visitors::Fb
