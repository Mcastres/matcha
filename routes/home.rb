class Matcha < Sinatra::Application

	# Root
	get "/" do
		erb :index
	end

	get "/setup" do


		@@client.query("CREATE TABLE IF NOT EXISTS `users`
							   (
								 `id` int(11) NOT NULL AUTO_INCREMENT,
								 `email` varchar(255) NOT NULL,
								 `username` varchar(255) NOT NULL,
								 `firstname` varchar(255) NOT NULL,
								 `lastname` varchar(255) NOT NULL,
								 `password` varchar(255) NOT NULL,
								 `age` integer NOT NULL DEFAULT '18',
								 `sexe` varchar(50) DEFAULT NULL,
								 `orientation` varchar(50) NOT NULL,
								 `bio` text DEFAULT NULL,
								 `interest` varchar(255) NOT NULL,
								 `liked` text NOT NULL,
								 `visited_by` varchar(255) NOT NULL,
								 `score` integer DEFAULT '0',
								 `creation_date` DATE NOT NULL,
								 `confirmation_date` DATE,
								 `token` varchar(255) DEFAULT NULL,
								 `remember_token` varchar(255) DEFAULT NULL,
								 `mode` integer NOT NULL DEFAULT '0',
								 `report` integer NOT NULL DEFAULT '0',
								 `blocked` varchar(255) NOT NULL,
								 `online` integer NOT NULL DEFAULT '0',
								 `connected` DATE DEFAULT NULL,
								 `location` varchar(255) DEFAULT NULL,
								 `profile` varchar(255) DEFAULT NULL,
								 `image2` varchar(255) DEFAULT NULL,
								 `image3` varchar(255) DEFAULT NULL,
								 `image4` varchar(255) DEFAULT NULL,
								 `image5` varchar(255) DEFAULT NULL,
								 `range_location` varchar(255) DEFAULT '20',
								 `range_age` varchar(255) DEFAULT '18-24',
								 `range_score` varchar(255) DEFAULT '0-1000',
								 `localisable` integer NOT NULL DEFAULT '1',
								 PRIMARY KEY (`id`)
							   ) ENGINE=MyISAM DEFAULT CHARSET=utf8;")

		   @@client.query("CREATE TABLE IF NOT EXISTS `matchs`
								   (
									 `id` int(11) NOT NULL AUTO_INCREMENT,
									 `username1` varchar(255) DEFAULT NULL,
									 `username2` varchar(255) DEFAULT NULL,
									 `chat` varchar(3000) NOT NULL,
									 PRIMARY KEY (`id`)
								   ) ENGINE=MyISAM DEFAULT CHARSET=utf8;")

		   @@client.query("CREATE TABLE IF NOT EXISTS `notifications`
								   (
									 `id` int(11) NOT NULL AUTO_INCREMENT,
									 `username` varchar(255),
									 `notification` varchar(255),
									 `link` varchar(255),
									 `seen` integer DEFAULT '0',
									 PRIMARY KEY (`id`)
								   ) ENGINE=MyISAM DEFAULT CHARSET=utf8;")

								  root = ::File.dirname(__FILE__).chomp("routes") + "public"
								  Dir.mkdir(root) unless File.exists?(root)
								  Dir.mkdir(root + "/images") unless File.exists?(root + "/images")
		flash[:success] = 'Database and table successfuly created'
		redirect "/"
	end


	get "/user1" do
		if !request.websocket?
			erb :user1
		else
			request.websocket do |ws|
	      			ws.onopen do
				        ws.send("Hello World!")
				        settings.sockets << ws
					end
				ws.onmessage do |msg|
					EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
				end
				ws.onclose do
					warn("websocket closed")
					settings.sockets.delete(ws)
				end
			end
		end
	end

end
