/*jslint browser: true, devel: true */

/**

=head1 UploadPedigrees.js

Dialogs for uploading pedigrees


=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>, based on code by
Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {


    $('#upload_pedigrees_link').click(function () {
        open_upload_pedigrees_dialog();
    });

    jQuery("#upload_pedigrees_dialog").dialog({
	autoOpen: false,	
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 75],
	buttons: {
            "Cancel": function () {
                jQuery('#upload_pedigrees_dialog').dialog("close");
            },
	    "Ok": function () {
		upload_pedigrees_file();
                jQuery('#upload_pedigrees_dialog').dialog("close");
		
	    },
	}
    });


    $("#pedigrees_upload_spreadsheet_info_dialog").dialog( {
	autoOpen: false,
	buttons: { "OK" :  function() { $("#pedigrees_upload_spreadsheet_info_dialog").dialog("close"); },},
	modal: true,
	position: ['top', 75],
	width: 900,
	autoResize:true,
    });

    
    $("#pedigrees_upload_spreadsheet_format_info").click( function () { 
	$("#pedigrees_upload_spreadsheet_info_dialog" ).dialog("open");
	
    });

    $("#pedigrees_upload_success_dialog_message").dialog({
	autoOpen: false,
	modal: true,
	buttons: {
            Ok: { id: "dismiss_pedigrees_upload_dialog",
                  click: function() {
		      //$("#upload_trial_form").dialog("close");
		      //$( this ).dialog( "close" );
		      location.reload();
                  },
                  text: "OK"
                }
        }
	
    });

    $('#upload_pedigrees_form').iframePostForm({
	json: true,
	post: function () {
            var uploadedPedigreesFile = $("#pedigrees_uploaded_file").val();
	    $('#working').dialog("open");
            if (uploadedPedigreesFile === '') {
		$('#working').dialog("close");
		alert("No file selected");
            }
	},
	complete: function (response) {
	    $('#working').dialog("close");
            if (response.error_string) {
		$("#upload_pedigrees_error_display tbody").html('');
		$("#upload_pedigrees_error_display tbody").append(response.error_string);


		$(function () {
                    $("#upload_pedigrees_error_display").dialog({
			modal: true,
			autoResize:true,
			width: 650,
			position: ['top', 250],
			title: "Errors in uploaded file",
			buttons: {
                            Ok: function () {
				$(this).dialog("close");
                            }
			}
                    });
		});
		return;
            }
            if (response.error) {
		alert(response.error);
		return;
            }
            if (response.success) {
		$('#pedigrees_upload_success_dialog_message').dialog("open");
		//alert("File uploaded successfully");
            }
	}
    });

        function upload_pedigrees_file() {
        var uploadFile = $("#pedigrees_upload_file").val();
        $('#upload_pedigrees_form').attr("action", "/ajax/pedigrees/upload");
        if (uploadFile === '') {
	    alert("Please select a file");
	    return;
        }
        $("#upload_pedigrees_form").submit();
    }

    function open_upload_pedigrees_dialog() {
	$('#upload_pedigrees_dialog').dialog("open");
	//add a blank line to design method select dropdown that dissappears when dropdown is opened 

    }
});
