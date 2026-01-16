class User {
  String? userId;
  String? userEmail;
  String? userName;
  String? userPhone;
  String? userPassword;
  String? userOtp;
  String? userRegdate;
  String? profileImage;

  User({
    this.userId,
    this.userEmail,
    this.userName,
    this.userPhone,
    this.userPassword,
    this.userOtp,
    this.userRegdate,
    this.profileImage,
  });

  User.fromJson(Map<String, dynamic> json) {
    userId = json['user_id']?.toString() ?? json['id']?.toString();
    userEmail = json['user_email'] ?? json['email'];
    userName = json['user_name'] ?? json['name'];
    userPhone = json['user_phone'] ?? json['phone'];
    userPassword = json['user_password'] ?? json['password'];
    userOtp = json['user_otp'] ?? json['otp'];
    userRegdate = json['user_regdate'] ?? json['regdate'] ?? json['registration_date'];
    profileImage = json['profile_image'];
  }

  get name => userName;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_id'] = userId;
    data['user_email'] = userEmail;
    data['user_name'] = userName;
    data['user_phone'] = userPhone;
    data['user_password'] = userPassword;
    data['user_otp'] = userOtp;
    data['user_regdate'] = userRegdate;
    data['profile_image'] = profileImage;
    return data;
  }
}


