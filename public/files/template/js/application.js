var OL = {
	init: function() {
		OL.Budget.init();
		OL.Search.init();
		OL.Work.init();
		OL.Comment.init();
	}
}

OL.Budget = {	
	init:function() {
		var budget = $('project_budget');
		if (budget) {
			budget.hide();
			$('track').setStyle({display:'inline'});
			OL.Budget.set(5000);
			
			new Control.Slider('handle', 'track', {
				sliderValue	: 5000,
				range				: $R(1000, 50000),
				values			: [1000,2000,3000,4000,5000,7500,10000,20000,30000,40000,50000],
				onSlide			: function(v) { OL.Budget.set(v); }
			});
		}
	},
	
	set:function(v) {
		var amt = v.toString();
		$('project_budget').writeAttribute('value', amt);
		$('budget').update(OL.Budget.format(amt));
	},

	format: function(amt) {
		var len = amt.length;
		return '$' + amt.substring(0, len-3) + ',' + amt.substring(len-3, len) + '+';
	}
};

OL.Search = {	
	/**
	 * Sets up the caches and adds observers
	 */
	init: function() {
		OL.Search.q = $('q');
		if (OL.Search.q) {
			OL.Search.q.observe('keyup', OL.Search.filter); 
			OL.Search.setupCache();
			OL.Search.filter();
			$('searchform').observe('submit', function(e) { Event.stop(e); });
		}
	},
	
	/**
	 * Caches li's, title and tags for each 
	 * article in arrays for later manipulation. 
	 */
	setupCache: function() {
		OL.Search.rows  = $A([]);
		OL.Search.cache = $A([]);
		$$('#archives ul li').each(function(li) {
			var kids  = li.descendants();
			var title = kids[1].innerHTML;
			var tags  = kids[2].innerHTML;
			OL.Search.cache.push([title, tags].join(' ').toLowerCase());
			OL.Search.rows.push(li);
		});
		OL.Search.cache_length = OL.Search.cache.length;
	},
	
	/**
	 * Runs the filter that only shows the rows 
	 * that have a score based on the search term.
	 */
	filter: function() {
		if (OL.Search.blank()) {
			OL.Search.rows.invoke('show');
			return;
		}
		OL.Search.displayResults(OL.Search.getScores($F(OL.Search.q).toLowerCase()));
	},
	
	/**
	 * Hides all the rows and shows on the ones with a score over 0
	 */
	displayResults: function(scores) {
		OL.Search.rows.invoke('hide');
		scores.each(function(score) { OL.Search.rows[score[1]].show(); })
	},
	
	/**
	 * Get the score of each row in the cache and return sorted 
	 * result set of [score, index of row in OL.Search.rows]
	*/
	getScores: function(term) {
		var scores = $A([]);
		for (var i=0; i < OL.Search.cache_length; i++) {
			var score = OL.Search.cache[i].score(term);
			if (score > 0) { scores.push([score, i]); }
		}
		// sort the scores descending
		return scores.sort(function(a, b) { return b[0] - a[0]; });;
	},
	
	/**
	 * returns true or false based on whether or not we have a search term
	 */
	blank: function() {
		($F(OL.Search.q) == '') ? true : false;
	}
}

OL.Work = {
	init: function() {
		$$('div.previews ul').each(function(ul) {
			new TabSet(ul.readAttribute('id'), {stopEvent:true}); 
		});
	}
}

OL.Comment = {
	init: function() {
		var form = $('comment-form');
		if (form) {
			new Form.Observer(form, 0.5, OL.Comment.updatePreview);
		}
	},
	
	updatePreview: function(e) {
		var author   = $F('comment_author');
		var email    = $F('comment_author_email');
		var url      = $F('comment_author_url');
		var body     = $F('comment');
		var gravatar = '/images/blank_gravatar.gif';
		var date 		 = new Date().format('longDate');
		
		// make sure we have a comments heading
		if (!$('comments')) { $('commentlist').insert({before: '<h2 id="comments">1 Comment</h2>'}); }
		
		// get gravatar if email exists
		if (email != '') { gravatar = 'http://www.gravatar.com/avatar.php?gravatar_id=' + hex_md5(email) + '&rating=PG&size=30&default=http://orderedlist.com/images/blank_gravatar.gif'; }
		
		// add link to author if exists
		if (url != '') { author = '<a href="' + url + '">' + author + '</a>'; }
		
		// update the preview
		$('comment_preview').update('<div class="wrapper"><div class="comment_body primary" id="live_comment_area">' + superTextile(body) + '</div><div class="comment_author secondary" id="live_comment_meta"><img src="' + gravatar + '" alt="Get your own gravatar for comments by visiting gravatar.com" id="comment_preview_img" width="30" height="30" /><cite>' + author + '</cite><p class="date"><a href="#">' + date + '</a></p></div></div>')
	}
}

document.observe('dom:loaded', function() { OL.init(); });