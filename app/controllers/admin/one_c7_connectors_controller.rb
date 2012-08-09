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
            xml = Nokogiri::XML.parse(File.read(path))

            #offers file loading here
            file = params[:one_c7][:offers_file]
            path1 = "#{Rails.root}/tmp/#{file.original_filename}"
            File.open(path1, "wb") { |f| f.write file.read }
            # Parsing
            offers_xml = Nokogiri::XML.parse(File.read(path1))

            taxonomy = Taxonomy.find_or_create_by_name(xml.css("Классификатор Группы Группа Наименование").first.text)
            taxonomy.update_attributes(:show_on_homepage => true)
            taxonomy.taxons.first.update_attributes(:name => xml.css("Классификатор Группы Группа Наименование").first.text, :code_1c => xml.css("Классификатор Группы Группа Ид").first.text)
            parse_groups_from_import_xml(xml.css("Классификатор Группы Группа Группы Группа"), taxonomy.taxons.first)
            parse_products(xml.css("Товар"))
            parse_products_offers_xml(offers_xml.css("Предложение"))

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
            if not product.variants.blank?
                price = 0
                product.variants.each do |var|
                    price = var.price if var.price.to_i != 0
                end
                product.price = price
                product.save
            end
        end
    end

    def parse_groups_from_import_xml(groups, taxon)
        groups.each do |group|
            new_taxon = Taxon.find_or_create_by_code_1c(group.css("Ид").first.text)
            if new_taxon.new_record?
                new_taxon.update_attributes(:name => group.css("Наименование").first.text, :taxonomy_id => taxon.taxonomy_id, :parent_id => taxon.id)
                parse_groups_from_import_xml(group.css("Группы Группа"), new_taxon)
            end
        end
    end

    def parse_products_offers_xml(products)
        products.each do |xml_product|
            product = Product.find_by_code_1c(xml_product.css("Ид").text.split('#').first)

            variant = Variant.find_or_initialize_by_code_1c(xml_product.css("Ид").text)
            variant.product_id = product.id
            variant.price = xml_product.css("ЦенаЗаЕдиницу").first.text
            variant.cost_price =xml_product.css("ЦенаЗаЕдиницу").last.text
            variant.count_on_hand = xml_product.css("Количество").text if not xml_product.css("Количество").text.blank?
            xml_product.css("ХарактеристикаТовара").each do |option|
                if ProductOptionType.where(:product_id => product.id, :option_type_id => OptionType.find_by_name(option.css("Наименование").text).id).blank?
                    product_option_type = ProductOptionType.new(:product => product, :option_type => OptionType.find_by_name(option.css("Наименование").text))
                    product_option_type.save
                end
                if OptionValue.find_by_name_and_option_type_id(option.css("Значение").text, OptionType.find_by_name(option.css("Наименование").text).id)
                    option_value = OptionValue.find_by_name_and_option_type_id(option.css("Значение").text, OptionType.find_by_name(option.css("Наименование").text).id)
                else
                    option_value = OptionValue.create(:option_type_id => OptionType.find_by_name(option.css("Наименование").text).id, :name => option.css("Значение").text,:presentation => option.css("Значение").text)
                end
                variant.option_values << option_value
            end
            variant.save
        end
    end

    def parse_products(products)
        products.each do |xml_product|
            product = Product.find_or_initialize_by_code_1c(xml_product.css("Ид").first.text)
            if product.new_record?
                product.name = xml_product.css("Наименование").first.text
                product.price = 0
                product.available_on = Time.now
                xml_product.css("Группы Ид").each do |xml_taxon|
                    product.taxons << Taxon.where(:code_1c => xml_taxon.text)
                end
                product.save!
            else
                product.update_attributes(:name => xml_product.css("Наименование").first.text, :price => 0)
                # Update taxon only have non-empty code_1c attribute
                xml_product.css("Группы Ид").each do |xml_taxon|
                    product.taxons << Taxon.where(:code_1c => xml_taxon.text)
                end
            end
        end
    end

end

