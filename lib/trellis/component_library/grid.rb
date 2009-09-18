#!/usr/bin/env ruby

#--
# Copyright &169;2001-2008 Integrallis Software, LLC.
# All Rights Reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'trellis/trellis'
require 'paginator'

module Trellis
  module CoreLibrary
    
    #
    #
    #
    class Grid < Trellis::Component
      is_stateful

      tag_name "grid"

      attr_accessor :source
      field :page_position, :persistent => true
      attr_reader :properties
      attr_reader :commands
      attr_reader :counter_method
      attr_reader :counter_method_arguments
      attr_reader :retrieve_block
      attr_reader :sort_properties
      field :sorted_by, :persistent => true
      field :sort_direction, :persistent => true, :default_value => :ascending

      def initialize
        @properties = []
        @sort_properties = []
        @commands = []
      end

      # must be called before rendering
      def columns(*syms)
        syms.each do |sym|
          @properties << sym
        end
      end

      def add_command(options=[])
        # extract options
        name = options[:name] if options
        page = options[:page] if options
        context = options[:context] if options
        image = options[:image] if options

        @commands << lambda do |tag, object|
          tid = tag.attr['tid']
          value = object.send(context.to_sym)
          url_root = tag.globals.page.class.url_root
          page = tag.globals.page.class.name unless page
          href = Trellis::DefaultRouter.to_uri(:url_root => url_root,
                                               :page => page,
                                               :event => name,
                                               :source => tid,
                                               :value => value)

          %{
          <a href="#{href}">
            <img src='#{image}'/>
          </a>
          }
        end
      end

      def sort_by_all_except(*syms)
        @sort_properties = @properties.reject { |property| syms.includes?(property)}
      end

      def sort_by(*syms)
        unless syms.first == :all
          @sort_properties = syms
        else
          @sort_properties = @properties
        end
      end

      def size_accessor(symbol, args)
        @counter_method, @counter_method_arguments = symbol, args
      end

      def retrieve_method(&block)
        @retrieve_block = block
      end

      # event handlers

      def on_page(page)
        @page_position = page.to_i # must use the cohersion built in capabilities
      end

      def on_sort(property)
        to_sym = property.to_sym
        if @sort_properties.include?(to_sym)
          if @sorted_by != to_sym
            @sorted_by = to_sym
          else
            @sort_direction = @sort_direction == :ascending ? :descending : :ascending
          end
        end
      end

      render do |tag|
        url_root = tag.globals.page.class.url_root
        # get the page object
        page = tag.globals.page
        # get the tag properties
        tid = tag.attr['tid']
        rows_per_page = tag.attr['rows_per_page'] || 3
        # get the instance of the component from the page
        grid = page.send("grid_#{tid}")
        # get the properties or columns
        properties = grid.properties
        # get the sort properties
        sort_properties = grid.sort_properties
        # current page
        current_page = grid.page_position || 1
        # sort information
        sorted_by = grid.sorted_by
        sort_direction = grid.sort_direction
        commands = grid.commands
        # get the source from either the tag or the component instance itself
        source = tag.attr['source'] || grid.source
        # get the array or collection that we can iterate over
        iterator = tag.globals.send(source.to_sym)

        builder = Builder::XmlMarkup.new

        # build the table
        builder.div(:class => "t-data-grid") {

          # configure pagination
          #TODO need to implement page ranging
          range = tag.attr['page_range'] || 5
          available_rows = 0
          unless grid.counter_method
            available_rows = iterator.length
          else
            unless grid.counter_method_arguments
              available_rows = iterator.send(grid.counter_method)
            else
              available_rows = iterator.send(grid.counter_method, grid.counter_method_arguments)
            end
          end

          # configure the pager
          pager = Paginator.new(available_rows, rows_per_page) do |offset, per_page|
            rows = nil
            unless grid.retrieve_method
              if sorted_by
                iterator = iterator.sort_by { |row| row.send(sorted_by) }
                iterator.reverse! if sort_direction == :descending
              end
              rows = iterator[offset, per_page]
            else
              rows = grid.retrieve_method.call
            end
            rows
          end

          # get the current page from the pager
          rows = pager.page(current_page)

          # render the pager control if necessary
          unless pager.number_of_pages < 2
            builder.div(:class => "t-data-grid-pager") {
              # loop over the pages
              (1..pager.number_of_pages).each do |page_num|
                if page_num == current_page
                  builder.span("#{page_num}", :class => "current")
                else
                  href = Trellis::DefaultRouter.to_uri(:url_root => url_root,
                                                       :page => page.class.name,
                                                       :event => "page",
                                                       :source => "grid_#{tid}",
                                                       :value => "#{page_num}")
                  builder.a("#{page_num}", :href => href, :title => "Go to page #{page_num}")
                end
              end
            }
          end

          # build the html
          builder.table(:class => "t-data-grid") {
            # header
            builder.thead {
              builder.tr {
                properties.each_index { |index|
                  property = properties[index]
                  field_name = property.to_s.humanize

                  if properties.length == index + 1
                    css_class = "#{field_name} t-last"
                  elsif index == 0
                    css_class = "#{field_name} t-first"
                  else
                    css_class = "#{field_name}"
                  end

                  sort_image = 'sortable.png'
                  if property == sorted_by
                    if sort_direction == :ascending
                      sort_image = 'sort-desc.png'
                    elsif sort_direction == :descending
                      sort_image = 'sort-asc.png'
                    end
                  end

                  unless sort_properties.include?(property)
                    builder.th(field_name, :class => css_class)
                  else
                    builder.th(:class => css_class) {
                      href = Trellis::DefaultRouter.to_uri(:url_root => url_root,
                                                           :page => page.class.name,
                                                           :event => "sort",
                                                           :source => "grid_#{tid}",
                                                           :value => "#{property}")
                      builder.a(field_name, :href => href)
                      builder.a(:href => href) {
                        builder.img(:alt => "[Sortable]", 
                                    :class => "t-sort-icon",
                                    :id => "#{property}:sort",
                                    :src => "#{url_root}/images/#{sort_image}",
                                    :name => "#{property}:sort")
                      }
                    }
                  end
                }
                # add columns for commands
                if commands && !commands.empty?
                  (1..commands.size).each do
                    builder.th
                  end
                end
              }
            }

            # body
            builder.tbody {
              # data
              index = 0
              rows.each do |item|
                if (rows.last_item_number - rows.first_item_number) == index + 1
                  css_class = "t-last"
                elsif index == 0
                  css_class = "t-first"
                else
                  css_class = nil
                end
                index = index + 1

                if css_class
                  builder.tr(:class => css_class) {
                    properties.each { |property|
                      field_value = item.send(property)
                      builder.td("#{field_value}", :class => "#{property}")
                    }
                    # add columns for commands
                    if commands && !commands.empty?
                      commands.each { |command|
                        builder.td { |td| td << command.call(tag, item)}
                      }
                    end
                  }
                else
                  builder.tr {
                    properties.each { |property|
                      field_value = item.send(property)
                      builder.td("#{field_value}", :class => "#{property}")
                    }
                    # add columns for commands
                    if commands && !commands.empty?
                      commands.each { |command|
                        builder.td { |td| td << command.call(tag, item)}
                      }
                    end
                  }
                end
              end if rows
            }
          }
        }
      end
    end
  end
end
