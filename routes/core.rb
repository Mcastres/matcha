class Matcha < Sinatra::Application

	def verify(sexe, orientation)
		if sexe != "men" && sexe != "women"
			flash[:danger] = 'YOU SHALL NOT PASS !'
			redirect "main/core"
		end

		if orientation != "Hetero" && orientation != "Bisexual" && orientation != "Homosexual"
			flash[:danger] = 'YOU SHALL NOT PASS !'
			redirect "main/core"
		end
	end

	def verify_extensions(image)
		if !image
			return 1
		end
		extension = ['jpeg', 'jpg', 'png']
		tab = image.to_s.split(".")
		if tab.count > 2
			return 0
		elsif !extension.include? tab[1]
			return 0
		else
			return 1
		end
	end

	def deg2rad(value)
		return (Math::PI * value)/180;
	end

	def distance(lat_a_degre, lon_a_degre, lat_b_degre, lon_b_degre)

		earth_rayon = 6378000 # Rayon de la terre en mètre

		lat_a = deg2rad(lat_a_degre);
		lon_a = deg2rad(lon_a_degre);
		lat_b = deg2rad(lat_b_degre);
		lon_b = deg2rad(lon_b_degre);

		result = earth_rayon * (Math::PI/2 - Math::asin( Math::sin(lat_b) * Math::sin(lat_a) + Math::cos(lon_b - lon_a) * Math::cos(lat_b) * Math::cos(lat_a)))
		return result / 1000;
	end


	#GET core
	get "/main/core" do
		authenticate!

		@me = find_user_by_username(session[:auth]['username'])[0]
		@notifications = @@client.query("SELECT * FROM notifications WHERE username = '#{session[:auth]['username']}'").each(:as.to_s => :array)

		if @notifications[0]
			@new = true
		end


		# ##### Filtre ultime
		@users = @@client.query("SELECT id, username, location, age, sexe, orientation, score, mode FROM users ORDER BY score DESC").each(:as.to_s => :array)

		# Coordinates
		@coords = @me['location'].split(",")
		# Range age
		range_age = @me['range_age'].split("-")
		# Range score
		range_score = @me['range_score'].split("-")

		# Valid users
		valid_users = []

		@users.each do |user|
			if user['mode'] == 1
				user_coords = user['location'].split(",")

				is_match = @@client.query("SELECT * FROM matchs WHERE username1 = '#{session[:auth]['username']}' AND username2 = '#{user['username']}' OR username2 = '#{session[:auth]['username']}' AND username1 = '#{user['username']}'").each(:as.to_s => :array)

				is_blocked = @@client.query("SELECT blocked FROM users WHERE id = '#{session[:auth]['id']}' AND blocked LIKE '%#{user['id']}%'").each(:as.to_s => :array)
				has_blocked = @@client.query("SELECT blocked FROM users WHERE id = '#{user['id']}' AND blocked LIKE '%#{session[:auth]['id']}%'").each(:as.to_s => :array)

				if is_match.empty? && is_blocked.empty? && has_blocked.empty?
					# Geoloc
					if (distance(@coords[0].to_f, @coords[1].to_f, user_coords[0].to_f, user_coords[1].to_f) <= @me['range_location'].to_f && user['age'].to_i >= range_age[0].to_i && user['age'].to_i <= range_age[1].to_i && user['score'].to_i >= range_score[0].to_i && user['score'].to_i <= range_score[1].to_i && user['username'] != @me['username'])
						# Orientation
						if ((@me['sexe'] == "men" && @me['orientation'] == "Hetero" && user['sexe'] == "women" && user['orientation'] == "Hetero") || (@me['sexe'] == "women" && @me['orientation'] == "Hetero" && user['sexe'] == "men" && user['orientation'] == "Hetero"))
							valid_users.push(user['username']) unless valid_users.include?(user['username'])
						elsif ((@me['sexe'] == "men" && @me['orientation'] == "Homosexual" && user['sexe'] == "men" && user['orientation'] == "Homosexual") || (@me['sexe'] == "women" && @me['orientation'] == "Homosexual" && user['sexe'] == "women" && user['orientation'] == "Homosexual"))
							valid_users.push(user['username']) unless valid_users.include?(user['username'])
						elsif (@me['orientation'] == "Bisexual" && user['orientation'] == "Bisexual")
							valid_users.push(user['username']) unless valid_users.include?(user['username'])
						end
					end
				end
			end
		end

		valid_users_string = valid_users.join("','")
		@users = @@client.query("SELECT * FROM users WHERE username IN('#{valid_users_string}')").each(:as.to_s => :array)

		##### end filtre

		if !request.websocket?
			erb :"main/core"
		else
			request.websocket do |ws|
	      			ws.onopen do
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

	get "/main/profile/:id" do
		authenticate!
		id = h(params[:id])

		has_blocked = @@client.query("SELECT blocked FROM users WHERE id = '#{id}' AND blocked LIKE '%#{session[:auth]['id']}%'").each(:as.to_s => :array)

		if !has_blocked.empty?
			redirect_flash("You can't reach this profile, reason: this person may blocked you or you blocked him", "danger", "/main/core")
		end

		@me = find_user_by_username(session[:auth]['username'])[0]

		@coords = @me['location'].split(",")

		if !@user = find_user_by_id(id)[0]
			redirect_flash("What are you trying to do", "danger", "/main/core")
		end

		@notifications = @@client.query("SELECT * FROM notifications WHERE username = '#{session[:auth]['username']}'").each(:as.to_s => :array)

		if @notifications[0]
			@new = true
		end

		link = "/main/profile/" + id.to_s
		delete_notification = @@client.query("DELETE FROM notifications WHERE username = '#{session[:auth]['username']}' AND link = '#{link}'")

		is_match = @@client.query("SELECT * FROM matchs WHERE username1 = '#{session[:auth]['username']}' AND username2 = '#{@user['username']}' OR username2 = '#{session[:auth]['username']}' AND username1 = '#{@user['username']}'").each(:as.to_s => :array)
		if !is_match.empty?
			@match = "/main/chat/#{session[:auth]['username']}/#{@user['username']}"
		end

		@id = id
		@images = [@user['profile'], @user['image2'], @user['image3'], @user['image4'], @user['image5']]
		@interest = @user['interest'].split(",")
		formated = "/" + id.to_s

		visited = @@client.query("SELECT visited_by FROM users WHERE id = '#{session[:auth]['id']}'").each(:as.to_s => :array)

		#Update visited
		if !visited[0]['visited_by'].nil?
			visited_by = visited[0]['visited_by'].split("/")
			i = 0
			visited_by.each do |id_visited|
				if id_visited.to_s == id.to_s
					i = 1
				end
			end
			if i == 0
				if session[:auth] && session[:auth]['username'] != @user['username']
					update_visited = @@client.query("UPDATE users SET visited_by = CONCAT(visited_by, '#{formated}') WHERE id = '#{session[:auth]['id']}'")

					@@client.query("INSERT INTO `notifications` (username, notification, link) VALUES ('#{@user['username']}', '#{session[:auth]['username']} visited your profile', '/main/profile/#{session[:auth]['id'].to_s}')")
				end
			end
		end

		#Select vistied, liked and matched only on his profile
		if id.to_s == session[:auth]['id'].to_s

			#Visited
			@visited_by = @@client.query("SELECT * FROM users WHERE visited_by LIKE '%#{session[:auth]['id']}%'").each(:as.to_s => :array)

			#Liked
			@liked_by = @@client.query("SELECT * FROM users WHERE liked LIKE '%#{session[:auth]['id']}%'").each(:as.to_s => :array)

			@matched_with = @@client.query("SELECT * FROM matchs WHERE username1 = '#{session[:auth]['username']}' OR username2 = '#{session[:auth]['username']}'").each(:as.to_s => :array)

		end

		if !request.websocket?
			erb :"main/profile"
		else
			request.websocket do |ws|
	      			ws.onopen do
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

	get "/main/like_user/:id" do
		id = h(params[:id])

		user = find_user_by_id(id)[0]

		#Find all liked profiles
		find_liked = @@client.query("SELECT liked, profile FROM users WHERE username = '#{session[:auth]['username']}'").each(:as.to_s => :array)

		#Check if there is no match with this person
		is_match = @@client.query("SELECT * FROM matchs WHERE username1 = '#{session[:auth]['username']}' AND username2 = '#{user['username']}' OR username2 = '#{session[:auth]['username']}' AND username1 = '#{user['username']}'").each(:as.to_s => :array)

		#If this is the first like
		if !find_liked[0]
			if session[:auth] && session[:auth]['id'].to_s != id.to_s && is_match.empty?

				formated = "/" + id
				update_liked = @@client.query("UPDATE users SET liked = CONCAT(liked, '#{formated}'), score = score + 1 WHERE username = '#{session[:auth]['username']}'")

				@@client.query("INSERT INTO `notifications` (username, notification, link) VALUES ('#{user['username']}', '#{find_liked['username']} liked your profile', '/main/profile/#{find_liked['id']}')")

				redirect_flash("You have liked this profile", "success", "main/profile/#{id}")
			else
				redirect_flash("You can\'t like this profile !", "danger", "main/profile/#{id}")
			end
		end

		#Unlike function
		i = 0
		liked = find_liked[0]['liked'].split("/")
		liked.each do |like_one|
			if id.to_s == like_one.to_s
				i = 1
				liked.delete(like_one)
				tab = liked.join("/")
				update_liked = @@client.query("UPDATE users SET liked = '#{tab}', score = score - 1 WHERE username = '#{session[:auth]['username']}'")

				string = user['username'] + " unliked you"
				find_notif = @@client.query("SELECT id FROM notifications WHERE username = '#{user['username']}' AND notification = '#{string}'").each(:as.to_s => :array)

				if find_notif[0].nil?
					@@client.query("INSERT INTO `notifications` (username, notification, link) VALUES ('#{user['username']}', '#{session[:auth]['username']} unliked you', '/main/profile/#{user['id'].to_s}')")
				end

				redirect_flash("You have unliked this profile :(", "danger", "main/profile/#{id}")
			end
		end

		#Like function
		if i == 0
			if session[:auth] && session[:auth]['id'].to_s != id.to_s && is_match.empty? && find_liked[0]['profile']
				formated = "/" + id
				update_liked = @@client.query("UPDATE users SET liked = CONCAT(liked, '#{formated}'), score = score + 1 WHERE username = '#{session[:auth]['username']}'")

				link = "/main/profile/" + session[:auth]['id'].to_s
				notification = session[:auth]['username'].to_s + " just liked your profile !"

				string = user['username'] + " just liked your profile !"
				find_notif = @@client.query("SELECT id FROM notifications WHERE username = '#{user['username']}' AND notification = '#{string}'").each(:as.to_s => :array)

				if find_notif[0].nil?
					@@client.query("INSERT INTO `notifications` (username, notification, link) VALUES ('#{user['username']}', '#{notification}', '#{link}')")
				end

				#Match function, if the profile like the person too, then it's a match !
				liked_by_id = user['liked'].split("/")
				liked_by_id.each do |liked|
					if liked.to_s == session[:auth]['id'].to_s
						string = ""
						@@client.query("INSERT INTO `matchs` (`username1`, `username2`, `chat`) VALUES ('#{session[:auth]['username']}', '#{user['username']}', '#{string}')")

						@@client.query("INSERT INTO `notifications` (username, notification, link) VALUES ('#{user['username']}', 'You matched with #{session[:auth]['username']}', '/main/chat/#{session[:auth]['username']}/#{user['username']}')")

						string = session[:auth]['username'] + " just liked your profile !"
						@@client.query("DELETE FROM notifications WHERE username = '#{user['username']}' AND notification = '#{string}'")

						@@client.query("UPDATE users SET score = score + 5 WHERE id = '#{id}' AND id = '#{session[:auth]['id']}'")
						flash[:success] = 'Matcha !'
						redirect "main/chat/#{session[:auth]['username']}/#{user['username']}"
					end
				end
				redirect_flash("You have liked this profile !", "success", "main/profile/#{id}")

			else
				redirect_flash("You can't like this profile !", "danger", "main/profile/#{id}")
			end
		end
	end

	get "/main/report_user/:id" do
		id = h(params[:id])

		if session[:auth] && session[:auth]['id'].to_s != id.to_s
			update_fake = @@client.query("UPDATE users SET report = report + 1 WHERE id = '#{id}'")
			redirect_flash("You have reported this account", "danger", "main/profile/#{id}")
		else
			redirect_flash("You can't report your own account you stupid !", "danger", "main/profile/#{id}")
		end
	end

	get "/main/block_user/:id" do
		id = h(params[:id])

		user = find_user_by_username(session[:auth]['username'])[0]

		#If this is the first block
		if !user['blocked']
			if session[:auth] && session[:auth]['id'].to_s != id.to_s
				formated = "/" + id
				update_blocked = @@client.query("UPDATE users SET blocked = CONCAT(blocked, '#{formated}') WHERE username = '#{session[:auth]['username']}'")
				redirect_flash("You have blocked this account", "danger", "main/profile/#{id}")
			else
				redirect_flash("You can't block your own account you stupid !", "danger", "main/profile/#{id}")
			end
		end

		#Unblock function
		i = 0
		blocked = user['blocked'].split("/")
		blocked.each do |block_one|
			if id.to_s == block_one.to_s
				i = 1
				blocked.delete(block_one)
				tab = blocked.join("/")
				update_blocked = @@client.query("UPDATE users SET blocked = '#{tab}' WHERE username = '#{session[:auth]['username']}'")
				redirect_flash("You have unblocked this account", "danger", "main/profile/#{id}")
			end
		end

		#Block function
		if i == 0
			if session[:auth] && session[:auth]['id'].to_s != id.to_s
				formated = "/" + id
				update_blocked = @@client.query("UPDATE users SET blocked = CONCAT(blocked, '#{formated}') WHERE username = '#{session[:auth]['username']}'")
				redirect_flash("You have blocked this account", "danger", "main/profile/#{id}")
			else
				redirect_flash("You can't block your own account you stupid !", "danger", "main/profile/#{id}")
			end
		end
	end

	get "/main/chat/:username1/:username2" do

		username1 = h(params[:username1])
		username2 = h(params[:username2])

		link = "/main/chat/" + username1 + "/" + username2
		link2 = "/main/chat/" + username2 + "/" + username1

		@notifications = @@client.query("SELECT * FROM notifications WHERE username = '#{session[:auth]['username']}'").each(:as.to_s => :array)

		if @notifications[0]
			@new = true
		end

		delete_notification = @@client.query("DELETE FROM notifications WHERE username = '#{session[:auth]['username']}' AND link = '#{link}' OR link = '#{link2}'")

		find_match = @@client.query("SELECT * FROM `matchs` WHERE username1 = '#{username1}' AND username2 = '#{username2}' OR username1 = '#{username2}' AND username2 = '#{username1}'").each(:as.to_s => :array)

		if find_match.empty? || (session[:auth]['username'] != username1 && session[:auth]['username'] != username2)
			redirect "main/core"
		end

		@user1 = find_user_by_username(username1)[0]
		@user2 = find_user_by_username(username2)[0]


		if @user1['username'] == session[:auth]['username']
			@username3 = @user2['profile']
			@user3_username = @user2['username']
			@user3_id = @user2['id']
		else
			@username3 = @user1['profile']
			@user3_username = @user1['username']
			@user3_id = @user1['id']
		end

		is_blocked = @@client.query("SELECT blocked FROM users WHERE id = '#{session[:auth]['id']}' AND blocked LIKE '%#{@user3_id}%'").each(:as.to_s => :array)
		has_blocked = @@client.query("SELECT blocked FROM users WHERE id = '#{@user3_id}' AND blocked LIKE '%#{session[:auth]['id']}%'").each(:as.to_s => :array)

		if !is_blocked[0].nil? || !has_blocked[0].nil?
			redirect_flash("You can't chat with this person, reason: he may blocked you or you blocked him", "danger", "main/profile/#{@user3_id}")
		end

		liked_us1 = @user1['liked'].split("/")
		liked_us2 = @user2['liked'].split("/")

		liked_us1.each do |like|
			if like == @user2['id'].to_s
				liked_us1.delete(like)
			end
		end
		tab1 = liked_us1.join("/")

		liked_us2.each do |like|
			if like == @user1['id'].to_s
				liked_us2.delete(like)
			end
		end
		tab2 = liked_us2.join("/")

		@@client.query("UPDATE users SET liked = '#{tab1}' WHERE username = '#{username1}'")
		@@client.query("UPDATE users SET liked = '#{tab2}' WHERE username = '#{username2}'")

		all_msg = @@client.query("SELECT chat FROM matchs WHERE username1 = '#{username1}' AND username2 = '#{username2}' OR username1 = '#{username2}' AND username2 = '#{username1}'").each(:as.to_s => :array)

		if !all_msg[0]['chat'].nil?
			@msg = all_msg[0]['chat'].split("@-|g~")
		end

		if !request.websocket?
			erb :"main/chat"
		else
			request.websocket do |ws|
	      			ws.onopen do
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

	post "/add_message" do

		username1 = h(params[:username1])
		username2 = h(params[:username2])
		msg = h(params[:msg])
		if username1 == session[:auth]['username']
			username3 = username2
		else
			username3 = username1
		end

		formated = "@-|g~" + session[:auth]['id'].to_s + msg.to_s
		@@client.query("UPDATE matchs SET chat = CONCAT(chat, '#{formated}') WHERE username1 = '#{username1}' AND username2 = '#{username2}' OR username1 = '#{username2}' AND username2 = '#{username1}'")

		notification = "You have a new message from " + session[:auth]['username']
		link = "/main/chat/" + username1 + "/" + username2
		@@client.query("INSERT INTO `notifications` (username, notification, link) VALUES ('#{username3}', '#{notification}', '#{link}')")

	end

	post "/add_notification" do

		username = h(params[:username])
		notification = h(params[:notification])
		link = h(params[:link])


	end

	#POST update
	post "/update_info" do
		# params.inspect
		sexe = h(params[:sexe])
		orientation = h(params[:orientation])
		bio = h(params[:bio])
		interest = h(params[:interest])
		min_age = h(params[:min_age])
		max_age = h(params[:max_age])
		min_score = h(params[:min_score])
		max_score = h(params[:max_score])
		location = h(params[:location])
		localisable = h(params[:localisable])
		code = h(params[:zip_code])
		age = h(params[:age])

		if min_score > max_score || min_age > max_age || (0..100).include?(age.to_i) == false
			flash[:danger] = 'YOU SHALL NOT PASS !'
			redirect "/main/core"
		end

		if bio.length > 200
			flash[:danger] = 'YOU SHALL NOT PASS !'
			redirect "/main/core"
		end

		if !code.empty?
			if code.length == 5
				code_postale = zip_code(code)
				code = code_postale[0].to_s + "," + code_postale[1].to_s
				@@client.query("UPDATE users SET location = '#{code}' WHERE username = '#{session[:auth]['username']}'")
			end
		end

		interest = interest.split(' ')
		interest.each do |char|
			if char[0] != '#'
				char.prepend("#")
			end
		end

		if !interest.empty?
			interest = interest.join(",")
			interest.prepend(",")
			@@client.query("UPDATE users SET interest = CONCAT(interest, '#{interest}') WHERE username = '#{session[:auth]['username']}'")
		end
		verify(sexe, orientation)

		range_age = min_age + "-" + max_age
		range_score = min_score + "-" + max_score

		@@client.query("UPDATE users SET sexe = '#{sexe}', orientation = '#{orientation}', age = '#{age}', range_age = '#{range_age}', range_score = '#{range_score}', range_location = '#{location}' WHERE username = '#{session[:auth]['username']}'")

		if localisable != "on"
			@@client.query("UPDATE users SET localisable = 0 WHERE username = '#{session[:auth]['username']}'")
		else
			@@client.query("UPDATE users SET localisable = 1 WHERE username = '#{session[:auth]['username']}'")
		end


		if !bio.empty?
			@@client.query("UPDATE users SET bio = '#{bio}' WHERE username = '#{session[:auth]['username']}'")
		end

		session[:auth]['sexe'] = sexe
		session[:auth]['orientation'] = orientation
		session[:auth]['bio'] = bio
		session[:auth]['interest'] = interest
		session[:auth]['age'] = age

		flash[:success] = 'Informations updated'
		redirect "main/core"

	end

	post "/update_settings" do
		email = h(params[:email]);
		firstname = h(params[:firstname]);
		lastname = h(params[:lastname]);

		find_email = @@client.query("SELECT * FROM users WHERE email = '#{email}'").each(:as.to_s => :array)
		if !email.empty?
			if email.match('[a-z0-9]+[_a-z0-9\.-]*[a-z0-9]+@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,4})') && find_email[0] == nil
				@@client.query("UPDATE users SET email = '#{email}' WHERE username = '#{session[:auth]['username']}'")
			else
				flash[:danger] = 'This address is already taken'
				redirect "main/core"
			end
		end

		if !firstname.empty?
			if firstname.length < 20
				@@client.query("UPDATE users SET firstname = '#{firstname}' WHERE username = '#{session[:auth]['username']}'")
			end
		end

		if !lastname.empty?
			if lastname.length < 20
				@@client.query("UPDATE users SET lastname = '#{lastname}' WHERE username = '#{session[:auth]['username']}'")
			end
		end

		flash[:success] = 'Settings updated'
		redirect "main/core"
	end
#
	post "/update_images" do


		extension = ["jpeg", "jpg", "png"]

		root = ::File.dirname(__FILE__).chomp("routes") + "public/images/" + session[:auth]['id'].to_s

		Dir.mkdir(root) unless File.exists?(root)

		if params[:profile]
			profile = params[:profile][:filename]
			f_profile = params[:profile][:tempfile]
			path_profile = root + "/" + profile
			name_p = profile.prepend("/images/#{session[:auth]['id']}/")
		end
		if params[:image2]
			image2 = params[:image2][:filename]
			f_image2 = params[:image2][:tempfile]
			path_image2 = root + "/" + image2
			name_2 = image2.prepend("/images/#{session[:auth]['id']}/")
		end
		if params[:image3]
			image3 = params[:image3][:filename]
			f_image3 = params[:image3][:tempfile]
			path_image3 = root + "/" + image3
			name_3 = image3.prepend("/images/#{session[:auth]['id']}/")
		end
		if params[:image4]
			image4 = params[:image4][:filename]
			f_image4 = params[:image4][:tempfile]
			path_image4 = root + "/" + image4
			name_4 = image4.prepend("/images/#{session[:auth]['id']}/")
		end
		if params[:image5]
			image5 = params[:image5][:filename]
			f_image5 = params[:image5][:tempfile]
			path_image5 = root + "/" + image5
			name_5 = image5.prepend("/images/#{session[:auth]['id']}/")
		end

		if (verify_extensions(profile) == 0) || (verify_extensions(image2) == 0) || (verify_extensions(image3) == 0) || (verify_extensions(image4) == 0) || (verify_extensions(image5) == 0)
			flash[:danger] = 'YOU SHALL NOT PASS !'
			redirect "main/core"
		else
			if f_profile
				File.open(path_profile, 'wb') do |f|
					f.write(f_profile.read)
				end
				file1 = File.open(path_profile, 'rb') {|file| file.read }
				if file1.include? '<?php'
					File.delete(path_profile)
					redirect_flash("Error", "danger", "/main/core")
				end
				@@client.query("UPDATE users SET profile = '#{name_p}' WHERE username = '#{session[:auth]['username']}'")
				session[:auth]['profile'] = name_p
			end

			if f_image2
			   File.open(path_image2, 'wb') do |f|
				   f.write(f_image2.read)
			   end
			   file2 = File.open(path_image2, 'rb') {|file| file.read }
			   if file2.include? "<?php"
				   File.delete(path_image2)
				   redirect_flash("Error", "danger", "/main/core")
			   end
			   @@client.query("UPDATE users SET image2 = '#{name_2}' WHERE username = '#{session[:auth]['username']}'")
			   session[:auth]['image2'] = name_2
			end

			if f_image3
				File.open(path_image3, 'wb') do |f|
				  f.write(f_image3.read)
			  	end
				file3 = File.open(path_image3, 'rb') {|file| file.read }
 			   if file3.include? "<?php"
 				   File.delete(path_image3)
 				   redirect_flash("Error", "danger", "/main/core")
 			   end
				@@client.query("UPDATE users SET image3 = '#{name_3}' WHERE username = '#{session[:auth]['username']}'")
				session[:auth]['image3'] = name_3
			end

			if f_image4
				File.open(path_image4, 'wb') do |f|
					f.write(f_image4.read)
			 	end
				file4 = File.open(path_image4, 'rb') {|file| file.read }
 			   if file4.include? "<?php"
 				   File.delete(path_image4)
 				   redirect_flash("Error", "danger", "/main/core")
 			   end
				@@client.query("UPDATE users SET image4 = '#{name_4}' WHERE username = '#{session[:auth]['username']}'")
				session[:auth]['image4'] = name_4
			end

			if f_image5
				File.open(path_image5, 'wb') do |f|
					f.write(f_image5.read)
				end
				file5 = File.open(path_image5, 'rb') {|file| file.read }
 			   if file5.include? "<?php"
 				   File.delete(path_image5)
 				   redirect_flash("Error", "danger", "/main/core")
 			   end
				@@client.query("UPDATE users SET image5 = '#{name_5}' WHERE username = '#{session[:auth]['username']}'")
				session[:auth]['image'] = name_5
			end

			files = Dir[root += "/*"]

			files_in_db = @@client.query("SELECT profile, image2, image3, image4, image5 FROM users WHERE username = '#{session[:auth]['username']}'").each(:as.to_s => :array)

			tab = [files_in_db[0]['profile'], files_in_db[0]['image2'], files_in_db[0]['image3'], files_in_db[0]['image4'], files_in_db[0]['image5']]
			tab.each do |files_db|
				if !files_db.nil?
					files_db = files_db.prepend(File.dirname(__FILE__).chomp("routes") + "public")
				end
			end

			compared = files - tab
			compared.inspect

			compared.each do |img|
				File.delete(img)
			end

			logfile = File.open(path_profile)

			flash[:success] = 'Your images have been successfuly uploaded'
			redirect "main/core"
		end
	end

end
