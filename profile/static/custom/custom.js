$([IPython.events]).on('notebook_loaded.Notebook', function(){
    // add here logic that should be run once per **notebook load**
    // (!= page load), like restarting a checkpoint

    var md = IPython.notebook.metadata;
    if(md.language){
        console.log('language already defined and is :', md.language);
    } else {
        md.language = 'ocaml' ;
        console.log('add metadata hint that language is ocaml...');
    }
});

$([IPython.events]).on('app_initialized.NotebookApp', function(){
    // add here logic that shoudl be run once per **page load**
    // like adding specific UI, or changing the default value
    // of codecell highlight.
    
    // Set tooltips to be triggered after 800ms
    IPython.tooltip.time_before_tooltip = 800;

    ////////////////////////////////////////////////////////////////////////
    // OCaml syntax highlighting for CodeMirror and highlight.js

    var iocaml_keywords = 
        'and as assert begin class constraint do done downto else end ' +
        'exception extern external for fun function functor if ' +
        'in include inherit inherit initializer lazy let match method ' +
        'method module mutable new of open open or private rec sig struct ' +
        'then to try type val val virtual when while with'
    ;

    var iocaml_builtins = 
        'bool char float int list unit array exn option int32 int64 nativeint ' +
        'format4 format6 lazy_t in_channel out_channel string true false ' +
        'ignore'
    ;

    // configure code mirror
    CodeMirror.defineMode("iocaml", function(config) {

      var words = { 
        'let': 'keyword',
        'false': 'builtin',
      };

      var k = iocaml_keywords.split(' ');
      for (var i in k) {
          words[k[i]] = 'keyword';
      }
      var k = iocaml_builtins.split(' ');
      for (var i in k) {
          words[k[i]] = 'builtin';
      }

      function tokenBase(stream, state) {
        var ch = stream.next();

        if (ch === '"') {
          state.tokenize = tokenString;
          return state.tokenize(stream, state);
        }
        if (ch === '(') {
          if (stream.eat('*')) {
            state.commentLevel++;
            state.tokenize = tokenComment;
            return state.tokenize(stream, state);
          }
        }
        if (ch === '~') {
          stream.eatWhile(/\w/);
          return 'variable-2';
        }
        if (ch === '`') {
          stream.eatWhile(/\w/);
          return 'quote';
        }
        if (/\d/.test(ch)) {
          stream.eatWhile(/[\d]/);
          if (stream.eat('.')) {
            stream.eatWhile(/[\d]/);
          }
          return 'number';
        }
        if ( /[+\-*&%=<>!?|]/.test(ch)) {
          return 'operator';
        }
        stream.eatWhile(/\w/);
        var cur = stream.current();
        return words[cur] || 'variable';
      }

      function tokenString(stream, state) {
        var next, end = false, escaped = false;
        while ((next = stream.next()) != null) {
          if (next === '"' && !escaped) {
            end = true;
            break;
          }
          escaped = !escaped && next === '\\';
        }
        if (end && !escaped) {
          state.tokenize = tokenBase;
        }
        return 'string';
      };

      function tokenComment(stream, state) {
        var prev, next;
        while(state.commentLevel > 0 && (next = stream.next()) != null) {
          if (prev === '(' && next === '*') state.commentLevel++;
          if (prev === '*' && next === ')') state.commentLevel--;
          prev = next;
        }
        if (state.commentLevel <= 0) {
          state.tokenize = tokenBase;
        }
        return 'comment';
      }

      return {
        startState: function() {return {tokenize: tokenBase, commentLevel: 0};},
        token: function(stream, state) {
          if (stream.eatSpace()) return null;
          return state.tokenize(stream, state);
        },

        blockCommentStart: "(*",
        blockCommentEnd: "*)",
        lineComment: null
      };
    });

    CodeMirror.defineMIME("text/x-iocaml", "iocaml");

    CodeMirror.requireMode('iocaml', function(){

        cells = IPython.notebook.get_cells();
        for(var i in cells){
            c = cells[i];
            if (c.cell_type === 'code') {
                // Force the mode to be ocaml
                // This is necessary, otherwise sometimes highlighting just doesn't happen.
                // This may be an IPython bug.
                c.code_mirror.setOption('mode', 'iocaml');

                c.auto_highlight()
            }
        }
    });   

    IPython.CodeCell.options_default['cm_config']['mode'] = 'iocaml';

    // configure highlight.js

    hljs.LANGUAGES['ocaml'] = function(hljs) {
      return {
        k: {
          keyword: iocaml_keywords,
          built_in: iocaml_builtins
        },
        c: [
          {
            cN: 'string',
            b: '"""', e: '"""'
          },
          {
            cN: 'comment',
            b: '\\(\\*', e: '\\*\\)'
          },
          {
            cN: 'class',
            bWK: true, e: '\\(|=|$',
            k: 'type',
            c: [
              {
                cN: 'title',
                b: hljs.UIR
              }
            ]
          },
          {
            cN: 'annotation',
            b: '\\[<', e: '>\\]'
          },
          hljs.CBLCLM,
          hljs.inherit(hljs.ASM, {i: null}),
          hljs.inherit(hljs.QSM, {i: null}),
          hljs.CNM
        ]
      }
    }(hljs);


        // Prevent the pager from surrounding everything with a <pre>
        IPython.Pager.prototype.append_text = function (text) {
            this.pager_element.find(".container").append($('<div/>')
                .html(IPython.utils.autoLinkUrls(text)));
        };
});

/*
$([IPython.events]).on('shell_reply.Kernel', function() {
    // Add logic here that should be run once per reply.

    // Highlight things with a .highlight-code class
    // The id is the mode with with to highlight
    $('.highlight-code').each(function() {
        var $this = $(this),
            $code = $this.html(),
            $unescaped = $('<div/>').html($code).text();
       
        $this.empty();

        // Never highlight this block again.
        this.className = "";
    
        CodeMirror(this, {
                value: $unescaped,
                mode: this.id,
                lineNumbers: false,
                readOnly: true
            });
    });
});
*/

