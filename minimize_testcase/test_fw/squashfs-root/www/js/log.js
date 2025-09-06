$(document).ready(function(){
	$('.logger_bot').each(function(index, element) {
		if($(this).is( "input" )){
			if($(this).attr("type") == 'radio'){
				$(this).click(function(){
					log_handler({'action':'click radio','element':element.id,'value':$(this).val()})
				});
			}else if($(this).attr("type") == 'checkbox'){
				$(this).click(function(){
					log_handler({'action':'click checkbox','element':element.id,'value':$(this).val()})
				});
			}else{
				$(this).on('keypress',function(e) {
					if(e.which == 13) {
						log_handler({'action':'key_enter','element':element.id})
					}
				});	
				$(this).on('blur',function(e) {
					log_handler({'action':'input','element':element.id,'input':$(this).val()})
				});
			}
		}else if($(this).is( "a" )){
			$(this).click(function(){
				log_handler({'action':'click','element':element.id})
			});
		}else if($(this).is( "div" )){
			$(this).click(function(){
				log_handler({'action':'click','element':element.id})
			});
		}else if($(this).is( "button" )){
			$(this).click(function(){
				log_handler({'action':'click','element':element.id})
			});
		}else if($(this).is( "select" )){
			$(this).on('click',function(e) {
				$(this).unbind();
				$(this).change(function(){
					log_handler({'action':'select option','element':element.id,'option':$(this).val()})
				});
			});
			
		}		
	});
});

function log_handler(content){
	if( 'undefined' == typeof(localStorage.logger_bot_enable) || "1" != localStorage.logger_bot_enable )
		return;
	else{
		var now = (new Date).getTime()
		content.time = now
		
		if( typeof(localStorage.logger_bot_history) == 'undefined')
			localStorage.logger_bot_history = ""
		else if( localStorage.logger_bot_history != "" )
			var histoty = jQuery.parseJSON( localStorage.logger_bot_history );
		else
			var histoty = []
		histoty.push(content)
		localStorage.logger_bot_history = JSON.stringify(histoty)
	}	
}


