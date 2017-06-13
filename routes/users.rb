class Matcha < Sinatra::Application

	#Some methods
	def empty_field(array)
		array.each do |argv|
			if argv.empty?
				flash[:danger] = 'Please complete all fields'
				redirect "users/sign_up"
				return 0
			end
		end
	end

	def check_password(password, confirm_password)
		if password.length < 6
		 	flash[:danger]= 'Password must contains at least 6 characters'
			redirect "users/sign_up"
		elsif password == confirm_password
			return 1
		end
	end


	# GET Users
	get "/users/sign_up" do
		erb :"users/sign_up"
	end

	get "/users/sign_in" do
	  erb :"users/sign_in"
	end

	get "/users/forget/:params" do
		@params = params[:params]
		erb :"users/forget"
	end

	get "/users/resend" do
		erb :"users/resend"
	end

	get "/users/confirm/:email/:token" do
		email = h(params[:email])
		token = h(params[:token])

		find_email = @@client.query("SELECT email FROM users WHERE token = '#{token}'").each(:as.to_s => :array)
		email_hashed = Digest::SHA1.hexdigest(find_email[0]['email'])

		if email_hashed == email
			confirm_user = @@client.query("UPDATE users SET mode = 1, token = NULL WHERE email = '#{find_email[0]['email']}'")
			flash[:success] = 'Your account has been confirmed !'
			redirect "users/sign_in"
		else
			flash[:danger] = 'This token is not valid'
			redirect "users/sign_in"
		end
	end

	#POST Users
   post "/users/resend" do
   	params.inspect
   	email = h(params[:email])
   	new_token = ([*('A'..'Z'),*('0'..'9')]-%w(0 1 I O)).sample(60).join

   	token = @@client.query("SELECT token, firstname FROM users WHERE email = '#{email}'").each(:as.to_s => :array)
   	if !token.empty?
   		if token[0]['token']
   			update_token = @@client.query("UPDATE users SET token = '#{new_token}' WHERE email = '#{email}'")
			email_hashed = Digest::SHA1.hexdigest(email)
   			subject = '<h2>Hello ' + token[0]['firstname'] +' !</h2><p>Here is a new confirmation link !</p><a href="http://localhost:3000/users/confirm/'+ email_hashed +'/'+ new_token +'">Confirm my account</a>'
   			Pony.mail(:to => email, :from => 'no-reply@matcha.com', :subject => 'Confirm your matcha\'s account', :html_body => subject.to_s, :body => 'You can confirm your account by clicking on this link')
   			flash[:success] = 'An email has been sent'
   			redirect "users/sign_in"
   		elsif token[0]['token'] == nil
   			flash[:danger] = 'Your account is already confirmed'
   			redirect "users/sign_in"
   		else
   			flash[:danger] = 'This token is not valid'
   			redirect "users/sign_in"
   		end
   	else
   		flash[:danger] = 'This address doesn\'t exists'
   		redirect "users/resend"
   	end
   end

   post '/users/sign_up' do
   	firstname = h(params[:firstname])
   	lastname = h(params[:lastname])
   	username = h(params[:username])
   	email = h(params[:email])
   	password = h(params[:password])
   	confirm_password = h(params[:confirm_password])

      if password.count("0-9") < 1
         flash[:danger] = "Password must contains one number"
         redirect "users/sign_up"
      end

   	array = []
   	array.push(firstname, lastname, username, email, password, confirm_password)
   	empty_field(array)

   	if check_password(password, confirm_password)
   		if email.match('[a-z0-9]+[_a-z0-9\.-]*[a-z0-9]+@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,4})')
   			password = Digest::SHA1.hexdigest(password)
   			email_uniq = @@client.query("SELECT email FROM users WHERE email = '#{email}'").each(:as.to_s => :array)
   			username_uniq = @@client.query("SELECT email FROM users WHERE username = '#{username}'").each(:as.to_s => :array)
   			if email_uniq.empty? || username_uniq.empty?
   				token = ([*('A'..'Z'),*('0'..'9')]-%w(0 1 I O)).sample(60).join
				string = ""
				loc = location
				loc = loc[0].to_s + "," + loc[1].to_s
   				@@client.query("INSERT INTO `users`(`email`, `username`, `firstname`, `lastname`, `password`, `sexe`, `visited_by`, `orientation`, `bio`, `interest`, `liked`, `blocked`, `score`, `creation_date`, `confirmation_date`, `token`, `remember_token`, `mode`, `location`) VALUES('#{email}','#{username}','#{firstname}','#{lastname}','#{password}', NULL, '#{string}', '#{string}', NULL, '', '/0', '#{string}', 0, NOW(), NULL, '#{token}', NULL, 0, '#{loc}')")

   				find_id = @@client.query("SELECT id FROM users WHERE email = '#{email}'").each(:as.to_s => :array)

				email_hashed = Digest::SHA1.hexdigest(email)
   				subject = '<h2>Hello ' + firstname +' !</h2><p>We welcome you on Matcha, please confirm your account just below by clicking the link ! </p><a href="http://localhost:3000/users/confirm/'+ email_hashed +'/'+ token +'">Confirm my account</a>'

   				Pony.mail(:to => email, :from => 'no-reply@matcha.com', :subject => 'Confirm your matcha\'s account', :html_body => subject.to_s, :body => 'You can confirm your account by clicking on this link')

   				flash[:success] = "An email has been sent in order to confirm your account"
   				redirect "users/sign_in"
   			else
   				flash[:danger] = "This account already exists"
   				redirect "users/sign_up"
   			end
   		end
   	end
   end

   post '/users/sign_in' do
   	username = h(params[:username])
   	password = h(params[:password])

   	if username.empty? || password.empty?
   		flash[:danger] = 'Please complete all fields'
   		redirect "users/sign_in"
   	else
		password = Digest::SHA1.hexdigest(password)
   		if find_password = @@client.query("SELECT password, mode FROM users WHERE username = '#{username}'").each(:as.to_s => :array)
			password.inspect
   			if !find_password.empty? && find_password[0]['password'] == password
   				if find_password[0]['mode'] == 1
   					get_auth = @@client.query("SELECT * FROM users WHERE username = '#{username}'").each(:as.to_s => :array)
   					session[:auth] = get_auth[0]
					session[:auth]['ip'] = request.ip
					loc = location
					loc = loc[0].to_s + "," + loc[1].to_s
					@@client.query("UPDATE users SET online = 1, location = '#{loc}' WHERE username = '#{username}'")

   					flash[:success] = 'You are now logged in'
   					redirect "main/core"
   				else
   					flash[:danger] = 'Your account is not activated'
   					redirect "users/sign_in"
   				end
   			else
   				flash[:danger] = 'Your password is incorrect'
   				redirect "users/sign_in"
   			end
   		else
   			flash[:danger] = 'This address doesn\'t exists'
   			redirect "users/sign_in"
   		end
   	end
   end

   post '/users/forget' do
   	if params[:email] != nil
   		email = h(params[:email])
   		if email.empty?
   			flash[:danger] = 'Please complete the field'
   			redirect "users/forget/email"
   		else
   			find_id = @@client.query("SELECT id, firstname FROM users WHERE email = '#{email}'").each(:as.to_s => :array)
   			if find_id.empty?
   				flash[:danger] = 'This address doesn\'t exists'
   				redirect "users/forget/email"
   			else
   				token = ([*('0'..'9')]-%w(0 1 I O)).sample(8).join
   				update_token = @@client.query("UPDATE users SET token = '#{token}' WHERE email = '#{email}'")

   				subject = '<h2>Hello ' + find_id[0]['firstname'] +' !</h2><p>It seems that you forgot your password ? Here is the code you have to put in the form: </p><h4>' + token + '</h4>'

   				Pony.mail(:to => email, :from => 'no-reply@matcha.com', :subject => 'Password reinitialisation', :html_body => subject.to_s, :body => 'Password reinitialisation')
   				flash[:success] = 'An email has been sent'
   				redirect 'users/forget/' + find_id[0]['id'].to_s + '-token'
   			end
   		end

   	elsif params[:token] != nil
   		token = h(params[:token])
   		url = h(params[:url])
   		formated = url.split('-')
   		find_token = @@client.query("SELECT token FROM users WHERE id = '#{formated[0]}'").each(:as.to_s => :array)
   		if token == find_token[0]['token']
   			flash[:success] = 'Setup your new password, chose a difficult one and easy to remember !'
   			redirect 'users/forget/' + formated[0] + '-password'
   		else
   			flash[:danger] = 'The code is incorrect, please send a new request'
   			redirect "users/forget/email"
   		end


   	elsif params[:password] != nil
   		password = h(params[:password])
   		confirmation_password = h(params[:confirmation_password])
   		url = h(params[:url])
   		formated = url.split('-')
   		if password.empty? || confirmation_password.empty?
   			flash[:danger] = 'Please complete all fields'
   			redirect 'users/forget/' + formated[0] + '-password'
   		end
   		if password.length < 6
   			flash[:danger] = 'Password must contains 6 characters'
   			redirect 'users/forget/' + formated[0] + '-password'
   		end
   		if password == confirmation_password
   			password = Digest::SHA1.hexdigest(password)

   			update_password = @@client.query("UPDATE users SET password = '#{password}', token = NULL WHERE id = '#{formated[0]}'")
   			find_email = @@client.query("SELECT firstname, email FROM users WHERE id = '#{formated[0]}'").each(:as.to_s => :array)

   			flash[:success] = 'Your password has been updated'
   			subject = '<h2>Hello ' + find_email[0]['firstname'] + ' !</h2><p>We confirm that you password has been successfuly updated !</p>'

   			Pony.mail(:to => find_email[0]['email'], :from => 'no-reply@matcha.com', :subject => 'Password reinitialisation', :html_body => subject.to_s, :body => 'Password reinitialisation')
   			redirect 'users/sign_in'
   		else
   			flash[:danger] = 'Passwords are not identical'
   			redirect 'users/forget/' + formated[0] + '-password'
   		end
   	end
   end

   get '/users/log_out' do
		if session[:auth]
			@@client.query("UPDATE users SET online = 0, connected = NOW() WHERE username = '#{session[:auth]['username']}'")
			session[:auth] = nil
		end
			flash[:success] = 'You are now logged out'
			redirect "users/sign_in"
   end
end
