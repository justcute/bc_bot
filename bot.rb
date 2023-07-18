require 'telegram/bot'
require 'nokogiri'
require 'open-uri'
require 'selenium-webdriver'
require 'rufus-scheduler'

URL = 'https://rejestracjapoznan.poznan.uw.gov.pl'

def parse_website
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  driver = Selenium::WebDriver.for :chrome, options: options

  driver.get(URL)

  sleep(5)
	button = driver.find_element(:xpath, '//button[contains(text(), "CUDZOZIEMCY - Złożenie wniosku: pobyt czasowy")]')
	driver.execute_script('arguments[0].scrollIntoView();', button)
	button.click
  sleep(2)

	button = driver.find_element(:xpath, '//button[text()="Dalej"]')
	driver.execute_script('arguments[0].scrollIntoView();', button)
	button.click
  sleep(4)


  html = driver.page_source
  doc = Nokogiri::HTML(html)


  elements = doc.css('span.vc-day-content:not(.is-disabled)')

	times = []
	elements.first(5).map(&:text).each do |selector|
		button = driver.find_element(:xpath, "//span[text()=\"#{selector}\"]")
		driver.execute_script('arguments[0].scrollIntoView();', button)
		button.click
		sleep(5)
	
		select_element = driver.find_element(:id, 'selectTime')
		options = select_element.find_elements(:tag_name, 'option')
		option_texts = options.map(&:text)
		times << "#{selector}: #{option_texts.join(", ")}"

		close_button = driver.find_element(:css, '.sweet-action-close')
		driver.execute_script('arguments[0].scrollIntoView();', close_button)
		close_button.click
		sleep(2)
	end

	if times == []
		text_content = 'No dates'
	else
		text_content = times.join("\n-------------------------------------------------------------------------\n")
	end

  driver.quit

  return text_content
end

token = ENV['YOUR_TELEGRAM_BOT_TOKEN']

Telegram::Bot::Client.run(token) do |bot|
	scheduler = Rufus::Scheduler.new
  scheduler_running = false

  bot.listen do |message|
		puts "[#{message.from.first_name}]:#{message}"
    case message.text
    when '/start_bc_parse'
      bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}!")
			if scheduler_running
        bot.api.send_message(chat_id: message.chat.id, text: "The scheduler is already running.")
      else
        scheduler.every '3m' do
          begin
            parsed_data = parse_website

            unless parsed_data == 'No dates'
              bot.api.send_message(chat_id: message.chat.id, text: parsed_data)
            end
          rescue StandardError => e
            bot.api.send_message(chat_id: message.chat.id, text: "Error occurred during parsing: #{e.message}")
          end
        end
        scheduler_running = true
        bot.api.send_message(chat_id: message.chat.id, text: "Scheduler started.")
      end
    when '/stop_bc_parse'
      if scheduler_running
        scheduler.stop
        scheduler_running = false
        bot.api.send_message(chat_id: message.chat.id, text: "Scheduler stopped.")
      else
        bot.api.send_message(chat_id: message.chat.id, text: "The scheduler is already stopped.")
      end
    when '/ping'
			begin
				response = parse_website
				bot.api.send_message(chat_id: message.chat.id, text: response)
			rescue StandardError => e
				bot.api.send_message(chat_id: message.chat.id, text: "Error occurred during parsing: #{e.message}")
			end
    else
      bot.api.send_message(chat_id: message.chat.id, text: "I'm sorry, I didn't understand that command.")
    end
  end
end
