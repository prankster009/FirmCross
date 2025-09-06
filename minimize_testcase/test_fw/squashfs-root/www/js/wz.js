	function get_wz_obj_success_cb(obj) {
		if(obj.api_return != 0){
			get_wz_obj_error_cb(obj)
			return;
		}
		WZ_ORIGINAL_OBJ_DATA = API.obj.copy(obj); 
		WZ_MODIFIED_OBJ_DATA = API.obj.copy(WZ_ORIGINAL_OBJ_DATA);
		
		if( 'undefined' != typeof(localStorage.lang) && "" != localStorage.lang)
			WZ_MODIFIED_OBJ_DATA.system.SystemP.language = localStorage.lang
		else
			WZ_MODIFIED_OBJ_DATA.system.SystemP.language = get_browser_lang()
		
		WZ_ORIGINAL_OBJ_DATA.timeZone.TimeZoneP.zonename = WZ_MODIFIED_OBJ_DATA.timeZone.TimeZoneP.zonename = tz2id_convertor()
		
		wz_auto_fw_control(WZ_ORIGINAL_OBJ_DATA.autofw.AutofwP.enable,'0')
		
		$('.2ghNamelbl').html(WZ_ORIGINAL_OBJ_DATA.wlanBasic.WlanBasicT[0].ssid);
		$('.2ghPWlbl').html(WZ_ORIGINAL_OBJ_DATA.wlanSecurity.WlanSecurityT[0].wpaPsk);
		$('.5ghNamelbl').html(WZ_ORIGINAL_OBJ_DATA.wlanBasic.WlanBasicT[1].ssid);
		$('.5ghPWlbl').html(WZ_ORIGINAL_OBJ_DATA.wlanSecurity.WlanSecurityT[1].wpaPsk);
		
	} 
	function get_wz_obj_error_cb(obj) {
		if(obj.api_return == 403){
			logout('sto')
			return;
		}else
			session_revocer('get_wz_basic_obj()')
	} 
	function get_wz_obj_data(obj_list){ 
		API.obj.get(obj_list, get_wz_obj_success_cb, get_wz_obj_error_cb); 
	}

	function get_wz_basic_obj(){
		get_wz_obj_data(WZ_OBJ_LIST)
	}
	
	var WIZARD_NOW
	var WIZARD_LAST
	
	//Wizard control
	function wizard_dialog_control(next_step, previous_step){
		WIZARD_NOW = next_step
		WIZARD_LAST = previous_step
		$("#loader_msg_main").html(L.common.lang_loader_msg_main)
		$('#loader').show();
		if(previous_step != ""){
			$("#"+previous_step).hide();
		}
		setTimeout(function(){ 
			$('#loader').hide();
			$("#"+next_step).show();
		}, 1500);
	}

	function show_license_agreement(){
		var license_lang = 'en'
		if( 'undefined' != typeof(localStorage.lang) && "" != localStorage.lang ){
			license_lang = localStorage.lang
		}else if( 'undefined' != typeof(LANG) && "" != LANG )
			license_lang = LANG
		
		var L_page = window.open("/license/"+license_lang+".html",'license');
		setTimeout(function(){ 
			L_page.document.title = L.wiz.lang_wiz_license_agreement_title;
		}, 500);
	}
	
	function loadXMLString(txt) 
	{
		try //Internet Explorer
		{
			xmlDoc=new ActiveXObject("Microsoft.XMLDOM");
			xmlDoc.async="false";
			xmlDoc.loadXML(txt);
			return(xmlDoc); 
		}
		catch(e)
		{
			try //Firefox, Mozilla, Opera, etc.
			{
				parser=new DOMParser();
				xmlDoc=parser.parseFromString(txt,"text/html");
				return(xmlDoc);
			}
			catch(e) {
				try 
				{
					xmlDoc = $.parseHTML(txt);
				}
				catch(e) {
					return(null);
				}
			}
		}
		return(null);
	}
	
	function show_privacy_policy(){
		$.get( "policy/public_policy.html", function( d ) {
			var dom = loadXMLString(d)
			var public_policy

			if(dom)
				public_policy = $(dom).find( ".wrapper-fluid" ).find(".privacy-policy-container").html();
			else{
				public_policy = ""
			}
						
			if( 'undefined' == typeof(public_policy) || "undefined" == public_policy || "" == public_policy ){
				var P_page = window.open("/policy/en.html",'policy');
			}else{
				var P_page = window.open("/policy/policy.html",'policy');						
				setTimeout(function(){ 
					P_page.document.body.innerHTML = public_policy;
					P_page.document.title = L.wiz.lang_wiz_privacy_policy_title				
				}, 500);
			}		
		}).fail(function() {
			var P_page = window.open("/policy/en.html",'policy');
		});
	}
	
	function get_pp_success_cb(obj) {
		if(obj.api_return != 0){
			get_pp_error_cb(obj)
			return;
		}	
	}
	
	function get_pp_error_cb(obj) {
		if(obj.api_return == 403){
			logout('sto')
			return;
		}
	}
	
	function prepare_privacy_policy(){
		API.info.get('getPloicy', get_pp_success_cb, get_pp_error_cb, 5000); 
	}
	

	function agree_license_agreement(){
		$('#getStarted').show();
		var checker = $('.radio').find('#spanChecker').hasClass('checked');
		if(!checker){
			update_checked(document.getElementsByName('lice'))
		}
		$('#agreement').hide();
	}
	
	function sel_mpt(country){
		if(typeof(country) == "undefined")
			country = $("#mpt").val()
		else
			$("#mpt").val(country)
		
		eval('var dy_id="L.mpt.'+$("#mpt option:selected").attr("id")+'"')
		$("#mpt").siblings( ".selectSpan" ).html("<p>"+eval(dy_id)+"</p>");
	}
	
	function accept_license(ele){
		if(ele.value == 0){
			ele.value = 1
			$('.radio').find('#spanChecker').addClass('checked');
			$('#licenseNotice').hide();
		}
		else{
			ele.value = 0
			$('.radio').find('#spanChecker').removeClass('checked');
		}
	}
	
	function wizard_license_goto_cancel() {
		var checker = $('.radio').find('#spanChecker').hasClass('checked');
		if(!checker){
			//alert('Please check the license checkbox.');
			$('#licenseNotice').show();
		}else
			wizard_cancel()
	}
	
	function wizard_license_goto_wifi() {
		var checker = $('.radio').find('#spanChecker').hasClass('checked');
		if(!checker){
			//alert('Please check the license checkbox.');
			$('#licenseNotice').show();
		} else {
			$('#getStarted, #licenseNotice').hide();
			$('#ethernet_cable_prompt').hide();
			$('#loader').show();
			sync_basic_info()
		}
	}
	
	function wizard_wan_type_handler(){
		if(DETECTED_WAN_TYPE == "2")
			wizard_dialog_control('wiz_dsl_setup','getStarted')
		else
			wizard_mpt_handler()
	}
	
	function wizard_dsl_goto_wifi() {
		var msg = ""
		if($("#dsl_acct").val() == ""){
			eval('var msg=L.wiz.lang_wiz_dsl_account_empty')
		}else if($("#dsl_pwd").val() == ""){
			eval('var msg=L.wiz.lang_wiz_dsl_password_empty')
		}
		
		if(msg != ""){
			alert(msg);
			return;
		}
				
		localStorage.setItem('dslAcct', $("#dsl_acct").val());
		localStorage.setItem('dslPwd',$("#dsl_pwd").val());
		
		WZ_MODIFIED_OBJ_DATA.wan.WanP.proto="2"
		WZ_MODIFIED_OBJ_DATA.pppoe.PppoeP.username=$("#dsl_acct").val()
		WZ_MODIFIED_OBJ_DATA.pppoe.PppoeP.password=$("#dsl_pwd").val()
		
		wizard_mpt_handler()
	}
	
	function wizard_mpt_handler(){
		if( 'undefined' != typeof(localStorage.mpt_support) && localStorage.mpt_support == "1" ){
			var mpt_data = jQuery.parseJSON( localStorage.mpt_data);
			var country_list = localStorage.mpt_country_list.split(",");
			var mpt_str_list = []
			var mpt_val_list = []
			country_list.forEach(function(country){
			  mpt_str_list.push("mpt_country_"+country)
			  mpt_val_list.push(country)
			});
								
			draw_select('mpt', mpt_str_list, mpt_val_list,'sel_mpt()', '');
			$.lang_load("mpt");
			setTimeout(function(){
				if( 'undefined' != typeof(localStorage.mpt_country) && localStorage.mpt_country != "")
					sel_mpt(localStorage.mpt_country)
			}, 500);

			wizard_dialog_control('wiz_wifi_mpt', WIZARD_NOW)
		}	
		else{
			wizard_dialog_control('settings',WIZARD_NOW)
		}
	}
	
	function mpt_dialog_back_control(){
		if(DETECTED_WAN_TYPE == "2")
			wizard_dialog_control('wiz_dsl_setup','wiz_wifi_mpt')
		else
			wizard_dialog_control('getStarted','wiz_wifi_mpt')
	}
	
	function wizard_mpt_goto_wifi() {
		var wifi_mpt_country = $('#mpt').val();
		MPT_OBJ_DATA.wlanMpt.WlanMptP.selectedCountry = localStorage.mpt_country = wifi_mpt_country
		wizard_dialog_control('settings', 'wiz_wifi_mpt')
	}
	
	
	function wifi_dialog_back_control(){
		if( 'undefined' != typeof(localStorage.mpt_support) && localStorage.mpt_support == "1" )
			wizard_dialog_control('wiz_wifi_mpt','settings')
		else
			wizard_dialog_control('getStarted','settings')
	}
	
	function wifi_validation(band, ssid, password){
		if(ssid == ""){
			eval('var msg=L.wiz.lang_wiz_wifi_'+band+'g_ssid_empty')
			alert(msg);
			return false;
		} else if ( !validation_ssid_ascii(ssid) ){
			eval('var msg=L.wiz.lang_wiz_wifi_'+band+'g_ssid_format')
			alert(msg);
			return false;
		} else if (password == ""){
			eval('var msg=L.wiz.lang_wiz_wifi_'+band+'g_pw_empty')
			alert(msg);
			return false;
		} else if(!validation_key(password)){
			alert(L.error_message.lang_error_message_err92);
			return false;
		}
		return true;
	}

	function wizard_wifi_goto_pw() {

		var name2Ghz = $('#2ghName').val().trim();
		var pw2Ghz = $('#2ghPW').val().trim();
		var name5Ghz = $('#5ghName').val().trim();
		var pw5Ghz = $('#5ghPW').val().trim();
		
		if( wifi_validation('2', name2Ghz, pw2Ghz) && wifi_validation('5', name5Ghz, pw5Ghz) ){
			localStorage.setItem('2ghName', name2Ghz);
			localStorage.setItem('2ghPW', pw2Ghz);
			localStorage.setItem('5ghName', name5Ghz);
			localStorage.setItem('5ghPW', pw5Ghz);
			var wifi_count = WZ_MODIFIED_OBJ_DATA.wlanBasic.WlanBasicT.length
			
			for (i=0; i < wifi_count; ++i) {
				if (WZ_MODIFIED_OBJ_DATA.wlanBasic.WlanBasicT[i].type == "2") {
					WZ_MODIFIED_OBJ_DATA.wlanBasic.WlanBasicT[i].ssid=name2Ghz
					WZ_MODIFIED_OBJ_DATA.wlanSecurity.WlanSecurityT[i].wpaPsk=pw2Ghz
					WZ_MODIFIED_OBJ_DATA.easyMeshBss.EasyMeshBssP.ssid=name2Ghz
					WZ_MODIFIED_OBJ_DATA.easyMeshBss.EasyMeshBssP.wpaPsk=pw2Ghz	
				}
				else if (WZ_MODIFIED_OBJ_DATA.wlanBasic.WlanBasicT[i].type == "5") {
					WZ_MODIFIED_OBJ_DATA.wlanBasic.WlanBasicT[i].ssid=name5Ghz
					WZ_MODIFIED_OBJ_DATA.wlanSecurity.WlanSecurityT[i].wpaPsk=pw5Ghz
					WZ_MODIFIED_OBJ_DATA.easyMeshBss.EasyMeshBssP.ssid5G=name5Ghz
					WZ_MODIFIED_OBJ_DATA.easyMeshBss.EasyMeshBssP.wpaPsk5G=pw5Ghz
				}
			}
			
			$('.2ghNamelbl').html(localStorage.getItem('2ghName'));
			$('.2ghPWlbl').html(localStorage.getItem('2ghPW'));
			$('.5ghNamelbl').html(localStorage.getItem('5ghName'));
			$('.5ghPWlbl').html(localStorage.getItem('5ghPW'));
			WZ_MODIFIED_OBJ_DATA.easyMeshBasic.EasyMeshBasicP.enable='1';	
			WZ_MODIFIED_OBJ_DATA.easyMeshBasic.EasyMeshBasicP.deviceRole='1'	
			wizard_dialog_control('routerPassword', 'settings')
		}
	}

	function wizard_pw_goto_sum() {
		var adminpw = $('#adminPW').val();
		if(adminpw == ""){
			alert(L.wiz.lang_wiz_router_pw_empty);
			return;
		}
		else if(!check_contain_space(adminpw)){
			alert(L.wiz.lang_wiz_router_pw_title + " " + L.error_message.lang_error_message_contain_space);
			return;
		}
		else if(! valid_ascii(adminpw) ){
			alert(L.error_message.lang_error_message_err29);
			return;
		}
		else {
			localStorage.setItem('adminPW', adminpw);
			wizard_dialog_control('summary', 'routerPassword')
			WZ_MODIFIED_OBJ_DATA.account.AccountT[0].password=adminpw
			
			$('#adminPWlbl').html(localStorage.getItem('adminPW'));
                        $("#routerPassword").hide();
                        $("#loader_msg_main").html(L.common.lang_loader_msg_main)
                        $('#loader').show();
		}
	}
	
	var wz_control_timer
	
	function wz_network_back_checker(){
		wz_control_timer = setInterval(function(){
			$.ajax({ cache: false,
				url: "echo.html",
				success: function (data) {
					clearInterval(wz_control_timer)
					$("#newNetwork").hide()
					
					$("#loader_msg_main").html(L.wiz.lang_wiz_internet_check_msg)
					$("#loader").show()
								
					var timeout = 5000
					prepare_mpt_data()
					if( WZ_CANCEL_FLAG == "1" )
						timeout = 1000
					setTimeout(function(){ 
						localStorage.setItem('setupStatus','Done');
						if( WZ_CANCEL_FLAG == "1" ){
							//window.location.href = "system-status.html";
							logout()
						}else{
							if(DETECTED_WAN_TYPE == "2"){
								setTimeout(function(){
									dsl_status_checker()
								}, 10000);
							}else{
								setTimeout(function(){
									internet_status_checker()
								}, 10000);
							}
							
						}
					}, timeout);
					
				},
				error: function (data){
					wizard_dialog_control('newNetwork', 'summary')
				}
			});	
		},5000)
	}

	function set_wz_obj_success_cb(obj){
		if(obj.api_return != 0){
			set_wz_obj_error_cb(obj)
			return;
		}
		setTimeout(function(){
			wz_network_back_checker()
		}, 75000);
		
	}

	function set_wz_obj_error_cb(obj) {
		if(obj.api_return == 403){
			$("#loader").hide()
			logout('sto')
			return;
		}else{
			if(WZ_CANCEL_FLAG == 1 && SAVE_RETRY < 3){
				SAVE_RETRY++
				session_revocer('set_wz_obj_data(WZ_MODIFIED_OBJ_DATA)')
			}else if( NORMAL_SAVE == 1 && SAVE_RETRY < 3){
				SAVE_RETRY++
				session_revocer('set_wz_obj_data(NORMAL_SAVE_TMP_OBJ)')
			}
			else{
				$("#loader").hide()
				show_alert(L.common.fail_title, L.common.save_fail)
			}
				
		}
	} 
	
	var NORMAL_SAVE_TMP_OBJ
	var NORMAL_SAVE = 0
	var SAVE_RETRY = 0

	function set_wz_obj_data(obj_content){
		if(typeof(obj_content) == 'string')
			API.obj.set(JSON.parse(obj_content), set_wz_obj_success_cb, set_wz_obj_error_cb);
		else if(typeof(obj_content) == 'object')
			API.obj.set(obj_content, set_wz_obj_success_cb, set_wz_obj_error_cb);
	}
		
	function wizard_sum_goto_net() {
		
		$('.2ghNamelbl').html(localStorage.getItem('2ghName'));
		$('.2ghPWlbl').html(localStorage.getItem('2ghPW'));
		$('.5ghNamelbl').html(localStorage.getItem('5ghName'));
		$('.5ghPWlbl').html(localStorage.getItem('5ghPW'));
		
		WZ_MODIFIED_OBJ_DATA.system.SystemP.doneWizard = "1"
		$('#'+WIZARD_NOW).hide();
		
		$('#loader').show();
		
		if('undefined' != typeof(localStorage.mpt_support) && localStorage.mpt_support == "1")
			WZ_MODIFIED_OBJ_DATA = UI.obj.merge(MPT_OBJ_DATA,WZ_MODIFIED_OBJ_DATA)
		
		var save_obj = $.extend(true, {}, WZ_MODIFIED_OBJ_DATA);
		
		if(DETECTED_WAN_TYPE == "1"){
			delete save_obj.wan;
			delete save_obj.pppoe;
		}
		
		SAVE_TMP_OBJ = $.extend(true, {}, save_obj);
		NORMAL_SAVE = 1
		set_wz_obj_data(save_obj)
	}
	
	function wiz_net_fail_handling(){
		
		if(DETECTED_WAN_TYPE == "2"){
			wizard_dialog_control('getStarted', 'wiz_net_fail')
		}else{
			wizard_dialog_control('getStarted', 'wiz_net_fail')
		}
	}
	
	function get_dsl_success_cb(obj) {
		if(obj.api_return != 0){
			get_info_error_cb(obj)
			return;
		}
		dsl_status = obj.vpnAction.status
		
		if(dsl_status == 'NOK' && DSL_CHECK_TIMER > 10){
			localStorage.setItem('setupStatus','');
			wizard_dialog_control('wiz_net_fail', 'summary')
		}
		else if(dsl_status == 'NOK' && DSL_CHECK_TIMER <= 10){
			setTimeout(function(){
				dsl_status_checker()
			}, 5000);
		}
		else{
			$("#loader").hide()
			prepare_privacy_policy()
			wizard_dialog_control('succ', 'summary')
		}
	}

	function get_dsl_error_cb(obj) {
		if(obj.api_return == 403){
			logout('sto')
			return;
		}
	} 
	
	var DSL_CHECK_TIMER = 0
	
	function dsl_status_checker(){
		DSL_CHECK_TIMER++
		API.info.get('vpnAction', get_dsl_success_cb, get_dsl_error_cb); 
	}
	
	function get_net_success_cb(obj) {
		if(obj.api_return != 0){
			get_net_error_cb(obj)
			return;
		}
		
		net_status = obj.connStatus.status
		
		if(net_status != '1'){
			localStorage.setItem('setupStatus','');
			wizard_dialog_control('wiz_net_fail', 'summary')
		}
		else{
			$("#loader").hide()
			prepare_privacy_policy()
			wizard_dialog_control('succ', 'summary')
		}
	}

	function get_net_error_cb(obj) {
		if(obj.api_return == 403){
			logout('sto')
			return;
		}
	}
	
	function internet_status_checker(){
		API.info.get('connStatus', get_net_success_cb, get_net_error_cb); 
	}

	function set_reg_info_success_cb(obj){
		if(obj.api_return != 0){
			set_reg_info_error_cb(obj)
			return;
		}
		if(obj.emailReg == "OK"){
			$("#mail_register_handler_message").html(L.wiz.lang_wiz_reg_mail_success)
			wizard_dialog_control('mail_register_handler', 'registerProduct')
			setTimeout(function(){
				wizard_dialog_control('congratulations', 'mail_register_handler')
			}, 5000);
			
		}else{
			$('.reg_next_btn').hide()
			$('.reg_retry_btn').show()
			$("#mail_register_handler_message").html(L.wiz.lang_wiz_reg_mail_fail)
			wizard_dialog_control('mail_register_handler', 'registerProduct')
			setTimeout(function(){
				wizard_dialog_control('registerProduct', 'mail_register_handler')
			}, 5000);
		}
		
	}

	function set_reg_info_error_cb(obj) {
		$("#loader").hide()
		if(obj.api_return == 403){
			logout('sto')
			return;
		}else{
			$('.reg_next_btn').hide()
			$('.reg_retry_btn').show()
			$("#mail_register_handler_message").html(L.wiz.lang_wiz_reg_mail_fail)
			wizard_dialog_control('mail_register_handler', 'registerProduct')
			setTimeout(function(){
				wizard_dialog_control('registerProduct', 'mail_register_handler')
			}, 5000);
		}
	} 

	function wizard_email_goto_congrats(action) {
		WZ_CHECK_OTA_FLAG = 1
		if(action == "reg"){
			if($('#userEmail').val() && validate_email($('#userEmail').val())){
				var subscribe = "0"
				if($("#subscribe").prop("checked") == true){
					subscribe = "1"
				}
				
				var reg_data = {"emailReg":{"email":$('#userEmail').val(),"future":subscribe}}
				$("#loader").show()
				API.info.set(reg_data, set_reg_info_success_cb, set_reg_info_error_cb);
			} else {
				alert(L.wiz.lang_wiz_reg_mail_empty)
			}
		} else {
			wizard_dialog_control('congratulations', 'registerProduct')
		}
	}

	function wizard_congrats_goto_finish() {
		var response = confirm(L.wiz.lang_wiz_cancel_confirm);
		if (response == true) {
			wizard_dialog_control('finish', 'congratulations')
		} 
		else {
			txt = "You pressed Cancel!";
		}
		
	}

	function wizard_setup_done() {
		localStorage.setItem('setupStatus','Done');
		$('#'+WIZARD_NOW).hide();
		$('#loader').show();
		
		setTimeout(function(){ 
			$('#loader').hide();
			//window.location.href = "system-status.html";
			logout()
		}, 12000);
	}
	
	function wizard_cancel_close(original){
		WZ_CANCEL_FLAG = 1
			
		if( WZ_MODIFIED_OBJ_DATA.system.SystemP.doneWizard != "1" ){
			if( 'undefined' != original && "1" == original ){
				var tmp_lang = WZ_MODIFIED_OBJ_DATA.system.SystemP.language
				//Revert to original state
				WZ_MODIFIED_OBJ_DATA = API.obj.copy(WZ_ORIGINAL_OBJ_DATA);
				WZ_MODIFIED_OBJ_DATA.system.SystemP.language = tmp_lang
			}
			
			WZ_MODIFIED_OBJ_DATA.system.SystemP.doneWizard = "1"
			//delete WZ_MODIFIED_OBJ_DATA.easyMeshBasic
			delete WZ_MODIFIED_OBJ_DATA.easyMeshBss
			//WZ_MODIFIED_OBJ_DATA.easyMeshBasic.EasyMeshBasicP.enable='1';	
			//WZ_MODIFIED_OBJ_DATA.easyMeshBasic.EasyMeshBasicP.deviceRole='1'	
			$("#unfinished").hide()
			$('#loader').show();
			NORMAL_SAVE = 0
			
			set_wz_obj_data(WZ_MODIFIED_OBJ_DATA)
		}else{
			$("#unfinished").hide()
			$('#loader').show();
			localStorage.setupStatus="Done"
			setTimeout(function(){ 
				//window.location.href = "system-status.html";
				logout()
			}, 85000);				
		}
	}
	
	function ota_fail_wizard_cancel() {
		$('#'+WIZARD_NOW).hide();
		WZ_CANCEL_FLAG = 1
		$("#unfinished").hide()
		$('#loader').show();
		localStorage.setupStatus="Done"
		setTimeout(function(){ 
			//window.location.href = "system-status.html";
			logout()
		}, 12000);				
	}
	function wizard_cancel() {
		var response = confirm(L.wiz.lang_wiz_cancel_confirm);
		if (response == true && localStorage.setupStatus != "Done") {
			$('#'+WIZARD_NOW).hide();
			$("#unfinished").show()
		} else if( response == true ){
			$('#'+WIZARD_NOW).hide();
			wizard_cancel_close()
		} 
		else {
			txt = "You pressed Cancel!";
		}
	}

	function get_wz_info_success_cb(obj) {
		if(obj.api_return != 0){
			get_wz_info_error_cb(obj)
			return;
		}
		WZ_INFO_DATA = API.obj.copy(obj);
		
		if(WZ_INFO_DATA.portStatus.WAN.WanPort0 == "1")
			NET_ETHERNET_PLUGIN = 1
		else
			NET_ETHERNET_PLUGIN = 0
		
		//set DETECTED_WAN_TYPE to 2 if wan is pppoe type
		if(WZ_INFO_DATA.autowan.detectType == "2")
			DETECTED_WAN_TYPE = "2"
		
		//Update firmware information
		$("#wiz_congrats_fw_current").html(WZ_INFO_DATA.RouterInfo.FWVersion)
		
		if(NET_ETHERNET_PLUGIN == 0){
			wizard_dialog_control('ethernet_cable_prompt','getStarted')
		}
		else 
			wizard_wan_type_handler()
	
	}
	
	function session_revocer(call_back){
		$.ajax({
				type: "POST",
				url: "cgi-bin/al.cgi",
				data: '{}',
				dataType : "text",
				cache: false,
				success: function(){
					eval(call_back)
				},
				error: function(){
					window.location.href = "/"	
				}
		});
	}
	
	function get_wz_info_error_cb(obj) {
		if(obj.api_return == 403){
			logout('sto')
			return;
		}else{
			session_revocer('sync_basic_info()')
		}
	} 

	function sync_basic_info(){
		API.info.get(WZ_INFO_LIST, get_wz_info_success_cb, get_wz_info_error_cb, 30000); 
	}
	
	function wiz_check_ota_success_cb(obj) {
		if(obj.api_return != 0){
			wiz_check_ota_error_cb(obj)
			return;
		}
		
		if( "0" != obj.checkFW.status && WZ_CHECK_OTA_FLAG == 1 ){
			$('#upgrade_fw').show();
			$('#tr_wiz_ota_uptodate').hide();
			$('#wiz_congrats_fw_latest').html(obj.checkFW.version);
			$('#upgrade_fw_btn').show();
		}else if("0" == obj.checkFW.status){
			$('#upgrade_fw').hide();
			$('#tr_wiz_ota_uptodate').show();
		}
	}

	function wiz_check_ota_error_cb(obj) {
		if(obj.api_return == 403){
			logout('sto')
			return;
		}
	}

	function wiz_ota_check_fw(){
		API.info.get('checkFW', wiz_check_ota_success_cb, wiz_check_ota_error_cb, 10000); 
	}

	var control_timer
	
	function reboot_back_checker_wiz(target_url, rd_url){
		var check_url = ""
		if( 'undefined' != typeof(target_url) && target_url != "")
			check_url = target_url
		clearTimeout(control_timer)
		control_timer = setInterval(function(){
			$("#loader_msg_warning").html(L.common.lang_reconnect)
			$("#loader_msg_warning").show()
			$.ajax({ cache: false,
				url: check_url+"echo.html",
				success: function (data) {
					clearInterval(control_timer)
					if('undefined' != typeof(rd_url) && rd_url != "")
						window.location.href = check_url+rd_url
					else{
						setTimeout(function(){
							$('#loader').hide();
							$("#loader_msg_warning").hidee()
							wizard_dialog_control('finish', 'congratulations')
						},10000)
					}
				},
				error: function (data){}
			});	
		},5000)
	}
	
	var OTA_STATUS_CHECK_TIMER
	
	function get_ota_status_success_cb(obj) {
		if(obj.api_return != 0 || obj.checkFW.fwstatus == "-1"){
			get_ota_status_error_cb(obj)
			return;
		}
				
		if( 95 < parseInt(obj.checkFW.fwstatus,10)){
			$("#loader_msg_main").html('<span>'+L.wiz.lang_wiz_ota_success_msg+'</span>')
			//$("#loader_msg_sub").show()
			control_timer = setTimeout(function(){
				reboot_back_checker_wiz()
			},20000)
		}else{
			OTA_STATUS_CHECK_TIMER = setTimeout(function(){
				check_ota_process_percentage()
			},2000)
			
		}
	} 
	function get_ota_status_error_cb(obj) {
		if(obj.api_return == 403){
			logout('sto')
			return;
		}else{
			upgrade_error_cb(obj)
		}
	}
	
	function check_ota_process_percentage(){
		clearTimeout(OTA_STATUS_CHECK_TIMER)
		API.info.get('checkFW', get_ota_status_success_cb, get_ota_status_error_cb); 
	}
	
	function upgrade_success_cb(obj) {
		if(obj.api_return != 0){
			upgrade_error_cb(obj)
			return;
		}
		
		OTA_STATUS_CHECK_TIMER = setTimeout(function(){
			check_ota_process_percentage()
		},1000)
	}

	function upgrade_error_cb(obj) {
		if(obj.api_return == 403){
			logout('sto')
			return;
		}
		$('#loader').hide();
		$("#ota_upgrade_fail").show()
	}

	function upgrade_fw(){
		$("#congratulations").hide()
		$('#loader').show();
		var fw_data = {"checkFW":{"version":WZ_INFO_DATA.checkFW.version, "status":"0", "fwstatus":"0"}}
		API.info.set(fw_data, upgrade_success_cb, upgrade_error_cb);
	}
	
	function set_autofw_obj_success_cb(obj) { 
		if(obj.api_return != 0){
			set_autofw_obj_error_cb(obj)
			return;
		}
		$("#loader").hide()
	} 
 	function set_autofw_obj_error_cb(obj) { 
		$("#loader").hide()
		if(obj.api_return == 403){
			logout('sto')
			return;
		}
	} 
	function set_autofw_obj_data(obj_content){ 
		if(typeof(obj_content) == 'string')
			API.obj.set(JSON.parse(obj_content), set_autofw_obj_success_cb, set_autofw_obj_error_cb); 
		else if(typeof(obj_content) == 'object') 
			API.obj.set(obj_content, set_autofw_obj_success_cb, set_autofw_obj_error_cb);
	}
	
	function wz_auto_fw_control(enable, action){
		enable = checkbox_switch('wiz_auto_fw', enable)
		
		var target_obj = {}
		target_obj.autofw = $.extend(true, {}, WZ_MODIFIED_OBJ_DATA.autofw);
		target_obj.autofw.AutofwP.enable = enable.toString()
		$("#loader").show()
		if(action=='0')
			return;
		else
			set_autofw_obj_data(target_obj)
	}
        
	var WPS_action = {"easyMeshWps":{"action":"wps"}};
        function wz_start_wps(old){
		wizard_dialog_control('meshinfowps', old)
		$('#count').hide()
                $('#fig').hide()
		$('#clip').show()
		setTimeout(function(){
			$('#count').show()
			$('#fig').show()
			$('#clip').hide()
			resizePopout();
			set_info_data(WPS_action);
			wps_countdown = 120
			$('#wpsCountdown_value').html(wps_countdown)
			wps_countdown_id = setInterval(wps_countdown_GUI, 1 * 1000)
			wps_detection()
		},15000);
	}
        function set_info_success_cb(obj) {
                //displayPopout('wps');
                setTimeout(function(){
                get_info_data(info_list);
                },2000);
        }
        function set_info_error_cb(obj) {
                if (obj.api_return == 403) {
                        logout('sto')
                }
        }
        function set_info_data(obj_content){
                if(typeof(obj_content) == 'string')
                        API.info.set(JSON.parse(obj_content), set_info_success_cb, set_info_error_cb);
                else if(typeof(obj_content) == 'object')
                        API.info.set(obj_content, set_info_success_cb, set_info_error_cb);
        }



	var WPS_action = {"easyMeshWps":{"action":"wps"}};
	var WPS_cancel = {"easyMeshWps":{"action":"cancel"}};
	var info_list=['easyMeshWps'];
	var info_data={};
        function reset_wps_status(flag){
		clearWPScontext()
		$('#count').hide()
                $('#fig').hide()
                $('#clip').show()
                set_info_data(WPS_cancel);
		if(flag=="1")
			wizard_dialog_control('meshinfoplug','meshinfowps')
		else
                	wizard_dialog_control('addNode','meshinfowps')

        }
	function get_info_success_cb(obj) {
                info_data = API.obj.copy(obj);
        }
        function get_info_error_cb(obj) {
                if (obj.api_return == 403) {
                        logout('sto')
                }
        }
        function get_info_data(info_list) {
                API.info.get(info_list, get_info_success_cb, get_info_error_cb);
        }
        function set_info_success_cb(obj) {
                //displayPopout('wps');
		console.log("pass")
        }
        function set_info_error_cb(obj) {
                if (obj.api_return == 403) {
                        logout('sto')
                }
        }
        function set_info_data(obj_content){
                if(typeof(obj_content) == 'string')
                        API.info.set(JSON.parse(obj_content), set_info_success_cb, set_info_error_cb);
                else if(typeof(obj_content) == 'object')
                        API.info.set(obj_content, set_info_success_cb, set_info_error_cb);
        }

        function wps_countdown_GUI() {
            wps_countdown--
            $('#wpsCountdown_value').html(wps_countdown)
            if (wps_countdown == 0) {
                clearWPScontext()
		wizard_dialog_control('meshinfofail','meshinfowps')                             
                //set_info_data(WPS_cancel);
            }
           get_info_data(info_list);
        }

	var save_action={"easyMeshNewAgent":{"action":"save"}};
        function wps_detection() {
		// Still not detect, keep polling every after 1 sec.
                // If countdown goes to 0 seconds, stopping polling.
                wscresult = info_data.wps_status;                                               
                console.log(wscresult);
                if(wps_countdown <=110){                                                         
	                if (wscresult == 'wps_successful' || wscresult == 'wps_failed') {
				if (wscresult == 'wps_successful'){
					wizard_dialog_control('meshinfopass','meshinfowps')
				}
				if ( wscresult == 'wps_failed')
					wizard_dialog_control('meshinfofail','meshinfowps')                             
                                closePopout();                                                                  
                                clearWPScontext()
                                return;
			}
		}
		if (wps_countdown > 0) {
			setTimeout(wps_detection, 1000 * 1)
		}
        }

        function clearWPScontext() {
		// Stop interval clock when back from WPS
		if (typeof (wps_countdown_id) != 'undefined')
			clearInterval(wps_countdown_id)
		// Stop Mesh polling
		wps_countdown = 0
		$('#count').show()
                $('#fig').show()
                $('#clip').hide()
        }
	var name_action={"easyMeshSetName":{"name":"NAME"}};
	function name_save(){
                if(!valid_node_name($("#name")[0]))
                        return ;
		name_action.easyMeshSetName.name = $("#name").val()
		set_info_data(save_action)
                setTimeout(function(){
                	set_info_data(name_action)
                },500);
		$("#name").val("")
		wizard_dialog_control('meshinfosave','meshinfoname')
		setTimeout(function(){
			wizard_dialog_control('addNode','meshinfosave')
                },6000);
	}
        function valid_node_name(I) {
                if (I.value.length < 1) {
                        alert(L.wiz.lang_wiz_mesh_name_error1);
                        I.value = I.defaultValue;
                        return false;
                }

                var re = new RegExp("[^a-zA-Z0-9-\\s-]+","gi");
                if (re.test(I.value)) {
                        alert(L.wiz.lang_wiz_mesh_name_error2);
                        I.value = I.defaultValue;
                        return false;
                }

                re = new RegExp("^[0-9-]","gi");
                if (re.test(I.value)) {
                        alert(L.wiz.lang_wiz_mesh_name_error3);
                        I.value = I.defaultValue;
                        return false;
                }

                ele_set_default(I,I.value);
                return true;
        }
