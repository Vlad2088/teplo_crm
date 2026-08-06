# Create admin user
user = User.find_or_create_by!(email: "admin@teplocrm.ru") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

puts "Created admin user: #{user.email}"

# Create services
services = [
  { name: "Монтаж тёплого пола", price_per_sqm: 800, description: "Укладка нагревательного мата, подключение" },
  { name: "Ремонт тёплого пола", price_per_sqm: 1200, description: "Диагностика и ремонт тёплого пола" },
  { name: "Демонтаж тёплого пола", price_per_sqm: 500, description: "Демонтаж старого покрытия и обогрева" },
  { name: "Замер помещения", price_per_sqm: 0, description: "Бесплатный выезд на замер" }
]

services.each do |attrs|
  Service.find_or_create_by!(name: attrs[:name]) do |s|
    s.price_per_sqm = attrs[:price_per_sqm]
    s.description = attrs[:description]
  end
end
puts "Created #{Service.count} services"

# Create products
products = [
  { name: "Тёплый пол Tesla 150 Вт/м²", sku: "TESLA-150", category: :warm_floor, brand: :tesla, unit: "м²",
    purchase_price: 1200, sale_price: 1800, stock_quantity: 100 },
  { name: "Тёплый пол Tesla 200 Вт/м²", sku: "TESLA-200", category: :warm_floor, brand: :tesla, unit: "м²",
    purchase_price: 1500, sale_price: 2200, stock_quantity: 80 },
  { name: "Тёплый пол XL-Pipe 160 Вт/м²", sku: "XLPIPE-160", category: :warm_floor, brand: :xl_pipe, unit: "м²",
    purchase_price: 1000, sale_price: 1600, stock_quantity: 60 },
  { name: "Терморегулятор Tesla Digital", sku: "TERMO-TSL-D01", category: :thermostat, brand: :tesla, unit: "шт",
    purchase_price: 2500, sale_price: 3800, stock_quantity: 30 },
  { name: "Терморегулятор XL-Pipe Basic", sku: "TERMO-XLP-B01", category: :thermostat, brand: :xl_pipe, unit: "шт",
    purchase_price: 1800, sale_price: 2800, stock_quantity: 25 },
  { name: "Подложка теплоизоляционная 3мм", sku: "UND-3MM", category: :underlay, brand: :other_brand, unit: "м²",
    purchase_price: 150, sale_price: 250, stock_quantity: 200 },
  { name: "Подложка теплоизоляционная 5мм", sku: "UND-5MM", category: :underlay, brand: :other_brand, unit: "м²",
    purchase_price: 200, sale_price: 320, stock_quantity: 150 }
]

products.each do |attrs|
  Product.find_or_create_by!(sku: attrs[:sku]) do |p|
    p.name = attrs[:name]
    p.category = attrs[:category]
    p.brand = attrs[:brand]
    p.unit = attrs[:unit]
    p.purchase_price = attrs[:purchase_price]
    p.sale_price = attrs[:sale_price]
    p.stock_quantity = attrs[:stock_quantity]
  end
end
puts "Created #{Product.count} products"

# Create clients
clients = [
  { name: "Иванов Иван Иванович", phone: "+7 (999) 123-45-67", email: "ivanov@example.com", address: "г. Москва, ул. Ленина, д. 1, кв. 10", client_type: :individual },
  { name: "ООО 'РемонтСтрой'", phone: "+7 (495) 765-43-21", email: "remont@example.com", address: "г. Москва, ул. Пушкина, д. 5, офис 101", client_type: :legal_entity, inn: "7700000001", kpp: "770001001" },
  { name: "Петров Пётр Петрович (ИП)", phone: "+7 (926) 111-22-33", email: "petrov@example.com", address: "г. Химки, ул. Мира, д. 3", client_type: :entrepreneur, inn: "500000000001" }
]

clients.each do |attrs|
  Client.find_or_create_by!(phone: attrs[:phone]) do |c|
    c.name = attrs[:name]
    c.email = attrs[:email]
    c.address = attrs[:address]
    c.client_type = attrs[:client_type]
    c.inn = attrs[:inn]
    c.kpp = attrs[:kpp]
  end
end
puts "Created #{Client.count} clients"

# Create sample order
client = Client.first
if Order.none?
  order = Order.create!(
    client: client,
    user: user,
    status: :lead,
    address: client.address,
    area_sqm: 25.5,
    notes: "Первичный звонок, нужен выезд на замер"
  )

  # Add order items
  product = Product.find_by(sku: "TESLA-150")
  service = Service.find_by(name: "Замер помещения")

  order.order_items.create!(
    item: product,
    quantity: 25.5,
    unit_price: product.sale_price,
    total_price: product.sale_price * 25.5
  ) if product

  order.order_items.create!(
    item: service,
    quantity: 1,
    unit_price: 0,
    total_price: 0
  ) if service

  puts "Created sample order ##{order.id}"
end

puts "Seeding completed!"
