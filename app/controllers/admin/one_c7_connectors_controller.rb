#encoding: UTF-8
class Admin::OneC7ConnectorsController < Admin::BaseController
    def create
        # If file present
        if params[:one_c7][:xml_file] && params[:one_c7][:offers_file]
            #import file loading here
            file = params[:one_c7][:xml_file]
            path = "#{Rails.root}/tmp/#{file.original_filename}"
            File.open(path, "wb") { |f| f.write file.read }
            # Parsing
            xml = REXML::Document.new(File.read(path))

            #offers file loading here
            file = params[:one_c7][:offers_file]
            path1 = "#{Rails.root}/tmp/#{file.original_filename}"
            File.open(path1, "wb") { |f| f.write file.read }
            # Parsing
            offers_xml = Nokogiri::XML.parse(File.read(path1))
            debugger
            taxonomy = Taxonomy.find(params[:one_c7][:taxonomy])
            xml.elements.first.elements.first.elements.each do |el|
                if el.expanded_name == 'Группы'
                    el.elements.each do |group|
                        # Always taxon, find or create it; rename if names different
                        if group.expanded_name == 'Группа'
                            # Children group
                            #parent_taxon = Taxon.find_by_code_1c(el.attribute('Группа').value)
                            #new_taxon = taxonomy.taxons.find_or_create_by_code_1c(el.attribute('Код').value)
                            #new_taxon.update_attributes(:name => el.attribute('Наименование').value, :parent_id => parent_taxon.id)
                            #else
                            # Root group
                            taxon = taxonomy.taxons.find_or_create_by_code_1c(group.elements[1].text)
                            taxon.update_attributes(:name => group.elements[2].text, :parent_id => taxonomy.taxons.first.id)
                        end
                    end
                    #else
                    # Always Product, find or create it; rename if names different
                    #   taxon = el.attribute('Группа') ? Taxon.find_by_code_1c(el.attribute('Группа').value) : Taxon.where(:taxonomy_id => params[:one_c7][:taxonomy], :parent_id => nil).first
                    #  parse_product(taxon, el) if taxon && el.attribute('Наименование').value.present?

                end
            end

            parse_products(xml.elements.first.elements[2].elements[5])
            parse_products_with_prices(offers_xml.css("Предложения"))

            set_product_price


            # delete xml file after parsing
            File.delete(path)
            File.delete(path1)
            redirect_to new_admin_one_c7_connector_path, :notice => t(:successful_1c_import)
        else
            flash[:error] = t(:no_selected_file)
            redirect_to new_admin_one_c7_connector_path
        end
    end

    private

    def set_product_price
        Product.all.each do |product|
            variant = product.variant
            variant.price = product.variants.second.price
            variant.cost_price = product.variants.second.cost_price
            debugger
        end
    end
    def parse_products_with_prices(products)
        products.children.each do |xml_product|

            debugger
            unique_flag = true
            product = Product.find_by_code_1c(xml_product.elements[1].text.split('#').first)
            if xml_product.elements[2].expanded_name == "Штрихкод"
                magic_number = 1
            else
                magic_number = 0
            end

            if xml_product.elements[4 + magic_number].expanded_name == "Статус"
                magic_number=magic_number+1
            end

            variant = Variant.find_or_initialize_by_code_1c(xml_product.elements[1].text)
            puts xml_product.elements[1].text
            variant.product_id = product.id
            variant.price = xml_product.elements[4 + magic_number].elements[1].elements[3].text
            variant.cost_price =xml_product.elements[4 + magic_number].elements[1].elements[3].text
            xml_product.elements.each do |el|
                if el.expanded_name == "Количество"
                variant.count_on_hand =xml_product.elements[5 + magic_number ].text
                end
            end
            xml_product.elements[3 + magic_number ].elements.each do |option|
                if ProductOptionType.where(:product_id => product.id, :option_type_id => OptionType.find_by_name(option.elements[1].text).id).blank?
                    product_option_type = ProductOptionType.new(:product => product, :option_type => OptionType.find_by_name(option.elements[1].text))
                    product_option_type.save
                end
                if OptionValue.find_by_name(option.elements[2].text)
                    option_value = OptionValue.find_by_name(option.elements[2].text)
                else
                    option_value = OptionValue.create(:option_type_id => OptionType.find_by_name(option.elements[1].text), :name => option.elements[2].text,:presentation => option.elements[2].text)
                end
                variant.option_values << option_value
            end
            variant.save
        end
    end

    def parse_products(products)
        products.elements.each do |xml_product|
            product = Product.find_or_initialize_by_code_1c(xml_product.elements[1].text)
            if product.new_record?
                product.name = xml_product.elements[3].text
                product.price = 0
                product.available_on = Time.now

                xml_product.elements[6].elements.each do |xml_taxon|
                    product.taxons << Taxon.where(:code_1c => xml_taxon.text)
                end

                product.save!
            else
                product.update_attributes(:name => xml_product.elements[3].text, :price => 0)
                # Update taxon only have non-empty code_1c attribute
                xml_product.elements[6].elements.each do |xml_taxon|
                    product.taxons << Taxon.where(:code_1c => xml_taxon.text)
                end
            end


        end
    end

    def parse_product(taxon, el)
        product = Product.find_or_initialize_by_code_1c(el.attribute('Код').value)

        if product.new_record?
            product.name = el.attribute('Наименование').value
            product.price = el.attribute('Цена').value.present? ? el.attribute('Цена').value : 0
            product.available_on = Time.now
            product.taxons << taxon
            product.save!
        else
            product.update_attributes(:name => el.attribute('Наименование').value, :price => el.attribute('Цена').value)
            # Update taxon only have non-empty code_1c attribute
            unless product.taxons.include?(taxon)
                old_taxon = product.taxons.select { |t| t.code_1c != nil }
                product.taxons.delete(old_taxon)
                product.taxons << taxon
            end
        end
    end
end

