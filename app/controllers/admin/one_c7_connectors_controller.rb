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
            path = "#{Rails.root}/tmp/#{file.original_filename}"
            File.open(path, "wb") { |f| f.write file.read }
            # Parsing
            offers_xml = REXML::Document.new(File.read(path))

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
            parse_products_with_prices(offers_xml.root.elements.first.elements[7])

            # delete xml file after parsing
            File.delete(path)
            redirect_to new_admin_one_c7_connector_path, :notice => t(:successful_1c_import)
        else
            flash[:error] = t(:no_selected_file)
            redirect_to new_admin_one_c7_connector_path
        end
    end

    private

    def parse_products_with_prices(products)
        products.elements.each do |xml_product|
            product = Product.find_by_code_1c(xml_product.elements[1].text.split('#').first)
            variant = Variant.new(:product_id => product.id,
                                  :price => xml_product.elements[4].elements[1].elements[3].text,
                                  :cost_price => xml_product.elements[4].elements[1].elements[3].text,
                                  :count_on_hand => xml_product.elements[5].text)

            xml_product.elements[3].elements.each do |option|
                option_value = OptionValue.find_or_create(:option_type_id => OptionType.find_by_name(option.elements[1]), :name => option.elements[2],:presentation => option.elements[2])
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

