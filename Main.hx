import Ball;
import Helper;
import Player;
import Switch;

import luxe.Color;
import luxe.Input;
import luxe.Rectangle;
import luxe.Sprite;
import luxe.Text;
import luxe.Vector;
import luxe.Visual;
import luxe.collision.shapes.Circle;
import luxe.collision.shapes.Polygon;
import luxe.collision.data.ShapeCollision;
import luxe.importers.tiled.TiledMap;
import luxe.importers.tiled.TiledObjectGroup;
import luxe.options.SpriteOptions;
import luxe.tilemaps.Tilemap;
import luxe.tween.Actuate;
import luxe.tween.easing.*;
import luxe.utils.Maths;

// import pgr.dconsole.DC;
import phoenix.geometry.Geometry;
import phoenix.Texture.FilterType;

using Lambda;
using thx.Arrays;
using thx.Iterators;
using thx.Iterables;

class Main extends luxe.Game
{
    // Constants

    private var CONSOLE_ENABLED = false;
    private var DEBUG_ENABLED = true;
    private var DEBUG_MOVE_STEP = 50;
    private var WORLD_BG_COLOR = 0x000000;

    // Variables

    private var camera_zoom = 0.75;
    private var debug_text:Text;
    private var drop_hovering = false;
    private var drop_index = -1;
    private var drop_block:Sprite;
    private var drop_blocks:Array<Sprite> = [];
    private var drop_tweening = false;
    private var map:TiledMap;
    private var map_scale = 1;
    private var max_ball_count = 20;
    private var mouse_pos:Vector;
    private var players:PlayerGroup;
    private var play_active = false;
    private var previous_drop_block:Sprite;
    private var random_verts = [];
    private var score_blocks:Array<TiledObject> = [];
    private var screen_fader:Fader;
    private var switches:Array<Switch> = [];

    private var physics:Physics;
    private var damp = 0.72;
    private var damp_air = 0.9;
    private var max_velocity = 1000;
    private var move_speed = 100;

    private var active_player( get, null ):Player;

    // Accessors

    public inline function get_active_player()
    {
        return this.players.active()[ 0 ];
    }

    // Constructor

    override function ready()
    {
        // Don't change the order of thse calls unless you know what you're doing!

        bind_input();
        configure_camera();
        // configure_console();
        configure_physics();
        create_players();
        create_map();
        create_map_objects();
        create_map_collision();
        configure_tweens();

        this.physics.paused = false;
        this.physics.
    }

    // Public methods

    function animate_drop_blocks( ?action = 'start' )
    {
        switch ( action )
        {
            case 'start':
                this.drop_tweening = true;
                var i = 1;

                for ( block in this.drop_blocks )
                    Actuate.tween( block.color, 1.0, { a: 0.0 } ).delay(0.1 * i++).onComplete(
                        function() { block.color.tween( 1.0, { a: 0.25 } ).reflect().repeat(); }
                    );
            case 'stop':
                this.drop_tweening = false;

                for ( block in this.drop_blocks )
                {
                    Actuate.stop( block.color );
                    Actuate.tween( block.color, 0.75, { a: 0.0 } );
                }
        }
    }

    function apply_input( dt:Float )
    {
        // if ( Luxe.input.inputdown( 'drop_ball' ) )
        // if ( Luxe.input.inputdown( 'move_down' ) )
        // if ( Luxe.input.inputdown( 'move_left' ) )
        // if ( Luxe.input.inputdown( 'move_right' ) )
        // if ( Luxe.input.inputdown( 'move_up' ) )

        if ( Luxe.input.inputdown( 'zoom_in' ) )
        {
            if ( DEBUG_ENABLED ) Luxe.camera.zoom += 0.05 * dt;
        }

        if ( Luxe.input.inputdown( 'zoom_out' ) )
        {
            if ( DEBUG_ENABLED ) Luxe.camera.zoom -= 0.05 * dt;
        }
    }

    function bind_input()
    {
        Luxe.input.bind_key(      'one', Key.key_1 );
        Luxe.input.bind_key(      'two', Key.key_2 );
        Luxe.input.bind_key(    'three', Key.key_3 );
        Luxe.input.bind_key(     'four', Key.key_4 );
        Luxe.input.bind_key(     'five', Key.key_5 );
        Luxe.input.bind_key(      'six', Key.key_6 );
        Luxe.input.bind_key(    'seven', Key.key_7 );
        Luxe.input.bind_key(    'eight', Key.key_8 );
        Luxe.input.bind_key(  'zoom_in', Key.kp_plus );
        Luxe.input.bind_key(  'zoom_in', Key.plus );
        Luxe.input.bind_key( 'zoom_out', Key.minus );
    }

    override function config( config:luxe.AppConfig )
    {
        config.preload.textures.push({ id: 'assets/tiles.png' });
        config.preload.texts.push({ id: 'assets/level_one.tmx' });

        return config;
    }

    function configure_camera()
    {
        this.screen_fader = Luxe.camera.add( new Fader({ name: 'fade' }) );

        Luxe.renderer.clear_color.rgb( WORLD_BG_COLOR );
        Luxe.camera.size = new Vector( 1152, 1024 );
        Luxe.camera.zoom = this.camera_zoom;
    }

    function configure_console()
    {
        if ( CONSOLE_ENABLED )
        {
            // DC.init();
            // DC.log("Switchbox test message.");
            // DC.registerObject(this, "Main");
        }
    }

    function configure_physics()
    {
        this.physics = Luxe.physics.add_engine( Physics );

        this.physics.draw = false;
        this.physics.paused = true;
        this.physics.max_velocity = this.max_velocity;

        Luxe.events.listen( 'physics.triggers.collide', ontrigger );
    }

    function configure_tweens()
    {
        Luxe.on( Luxe.Ev.init, function(_) { this.screen_fader.up( 1.0 ); });
        for ( _switch in this.switches ) _switch.show();
        animate_drop_blocks( 'start' );
    }

    function create_hud()
    {
        this.hud_batcher = new Batcher( Luxe.renderer, 'hud_batcher' );
            //we then create a second camera for it, default options
        var hud_view = new Camera();
            //then assign it
        hud_batcher.view = hud_view;
            //the default batcher is stored at layer 1, we want to be above it
        hud_batcher.layer = 2;
            //the add it to the renderer
        Luxe.renderer.add_batch(hud_batcher);

            //Now draw some text and the bar
        var small_amount = Luxe.screen.h * 0.05;

        Luxe.draw.box({
            x : 0, y : Luxe.screen.h - small_amount,
            w : Luxe.screen.w, h: small_amount,
            color : new Color().rgb(0xf0f0f0),
                //here is the key, we don't store it in the default batcher, we make a second batcher with a different camera
            batcher : hud_batcher
        });

        Luxe.draw.text({
            text : 'A HUD!',
            point_size : small_amount * 0.75,
            bounds : new Rectangle(small_amount/2, Luxe.screen.h - small_amount, Luxe.screen.w, small_amount),
            color : new Color().rgb(0xff4b03),
            batcher : hud_batcher,
            align_vertical : TextAlign.center
        });

        Luxe.draw.line({
            p0 : new Vector(Luxe.screen.w/2, 0),
            p1 : new Vector(Luxe.screen.w/2, Luxe.screen.h),
            color : new Color(1,1,1,0.3),
            batcher : hud_batcher
        });
        Luxe.draw.line({
            p0 : new Vector(0, Luxe.screen.h/2),
            p1 : new Vector(Luxe.screen.w, Luxe.screen.h/2),
            color : new Color(1,1,1,0.3),
            batcher : hud_batcher
        });

        line_one = Luxe.draw.line({
            p0 : new Vector(Luxe.screen.w/2, 0),
            p1 : new Vector(Luxe.screen.w/2, Luxe.screen.h),
            color : new Color(1,1,1,0.5).rgb(0xff440b),
            batcher : hud_batcher
        });

        line_two = Luxe.draw.line({
            p0 : new Vector(0, Luxe.screen.h/2),
            p1 : new Vector(Luxe.screen.w, Luxe.screen.h/2),
            color : new Color(1,1,1,0.5).rgb(0xff440b),
            batcher : hud_batcher
        });

    }

    function create_map( level_name = "level_one" )
    {
        var map_data = Luxe.resources.text( 'assets/${level_name}.tmx' ).asset.text;
        this.map = new TiledMap({ format: 'tmx', tiled_file_data: map_data });
        this.map.display({ scale: this.map_scale, filter: FilterType.nearest });
    }

    function create_map_objects()
    {
        var current_id = 0;
        var current_row = 0;
        var current_type = LEFT_SWITCH;
        var current_y = 0.0;
        var current_switch;

        this.switches = [];

        for ( group in this.map.tiledmap_data.object_groups )
            for ( object in group.objects )
                switch ( group.name )
                {
                    case 'drop_regions':
                        this.drop_blocks.push(
                            new Sprite({
                                color: new Color( 1, 1, 1, 0.25 ),
                                centered: false,
                                depth: 99,
                                pos: new Vector( object.pos.x, object.pos.y ),
                                size: new Vector( object.width, object.height ),
                                visible: true
                            })
                        );
                    case 'score_regions':
                        this.score_blocks.push( object );
                    case 'switches':
                        if ( object.pos.y > current_y )
                        {
                            current_row += 1;
                            current_y = object.pos.y;
                        }

                        switch ( object.type )
                        {
                            case 'left_switch':
                                current_type = LEFT_SWITCH;
                            case 'right_switch':
                                current_type = RIGHT_SWITCH;
                        }

                        this.switches.push(
                            new Switch({
                                sprite: Helper.create_sprite_from_tile( this.map, object ),
                                name: 'switch_${current_id}',
                                row: current_row,
                                type: current_type,
                                visible: false
                            })
                        );

                        current_id += 1;
                }

        this.physics.switches = this.switches;

        this.debug_text = new Text({
            align: TextAlign.left,
            align_vertical: TextAlign.top,
            bounds: new Rectangle(0, 0, 1000, 120),
            color: new Color().rgb(0xffffff),
            font: Luxe.renderer.font,
            point_size: 32,
            pos: Luxe.camera.screen_point_to_world( new Vector( 10, 10 ) )
        });
    }

    function create_map_collision()
    {
        for ( group in this.map.tiledmap_data.object_groups )
        {
            for ( object in group.objects )
            {
                switch ( object.type )
                {
                    case 'wall':
                        var shape = Polygon.rectangle(
                            object.polyobject.origin.x,
                            object.polyobject.origin.y,
                            object.width,
                            object.polyobject.points[1].y - object.polyobject.points[0].y,
                            false
                        );

                        shape.tags[ 'type' ] = 'wall';
                        this.physics.obstacle_colliders.push( shape );
                }
            }
        }
    }

    function create_players()
    {
        this.players = new PlayerGroup( 2 );
        this.players.get( 0 ).take_turn();
        this.physics.balls = this.players.balls.items;
    }

    function drop_ball( index:Int )
    {
        var ball = active_player.balls.next_available();
        if ( ball != null ) ball.drop_in( this.drop_blocks[ index ].pos.x + ( this.map.tile_width / 2 ) );
    }

    override function onkeyup( e:KeyEvent )
    {
        switch ( e.keycode )
        {
            case Key.escape:
                Luxe.shutdown();
            case Key.space:
                if ( DEBUG_ENABLED ) for ( s in this.switches ) s.flip();
            case Key.key_0:
                if ( DEBUG_ENABLED ) this.physics.draw = !this.physics.draw;
            case Key.key_h:
                if ( DEBUG_ENABLED )
                {
                    toggle_layers( true );
                    for ( s in this.switches ) s.hide();
                }
            case Key.key_r:
                if ( DEBUG_ENABLED )
                {
                    var a = 0;
                    for ( s in this.switches )
                    {
                        a += 1;
                        if ( a % Math.floor( Math.random() * 5 ) == 0 ) s.flip();
                    }
                }
            case Key.key_s:
                if ( DEBUG_ENABLED )
                {
                    toggle_layers( false );
                    for ( s in this.switches ) s.show();
                }
            case Key.key_z:
                if ( DEBUG_ENABLED )
                {
                    Luxe.camera.zoom = 0.0;
                    Actuate.tween( Luxe.camera, 1.0, { zoom: this.camera_zoom } ).ease( luxe.tween.easing.Back.easeOut );
                }
        }
    }

    override function onmousemove( e:MouseEvent )
    {
        this.mouse_pos = Luxe.camera.screen_point_to_world( e.pos );
        this.drop_hovering = false;

        for ( i in 0...this.drop_blocks.length )
        {
            this.drop_block = this.drop_blocks[ i ];

            if ( this.previous_drop_block == null )
                this.previous_drop_block = this.drop_block;

            if ( this.mouse_pos.x > this.drop_block.pos.x
                 && this.mouse_pos.x < this.drop_block.pos.x + this.drop_block.size.x 
                 && this.mouse_pos.y > this.drop_block.pos.y
                 && this.mouse_pos.y < this.drop_block.pos.y + this.drop_block.size.y )
            {
                if ( this.drop_tweening ) animate_drop_blocks( 'stop' );

                if ( this.drop_block != this.previous_drop_block )
                {
                    Actuate.tween( this.drop_block.color, 0.25, { a: 0.5 } );
                    Actuate.tween( this.previous_drop_block.color, 0.25, { a: 0.0 } );
                }

                this.previous_drop_block = this.drop_block;
                this.drop_index = i;
                this.drop_hovering = true;
            }
        }

        if ( !this.drop_hovering )
        {
            this.drop_index = -1;
            this.drop_block = null;
            this.previous_drop_block = null;

            if ( !this.drop_tweening ) animate_drop_blocks( 'start' );
        }
    }

    override function onmouseup( e:MouseEvent )
    {
        if ( this.drop_hovering && e.button == MouseButton.left && !this.play_active )
        {
            drop_ball( this.drop_index );
            this.play_active = true;
        }
    }

    function ontrigger( collisions:Array<ShapeCollision> )
    {
        var ball, inc, collided_ball, collided_name, collided_switch, collided_type;

        for ( collision in collisions )
        {
            ball = this.players.balls.named( collision.shape1.name );
            collided_name = collision.shape2.name;
            collided_type = collision.shape2.tags[ 'type' ];

            switch ( collided_type )
            {
                // Ball has collided with another ball
                case 'ball':
                    if ( ball.is_strafing() ) break;

                    collided_ball = this.players.balls.named( collided_name );
                    collided_switch = this.switches.find( function(i) return i.ball == collided_ball );

                    if ( collided_switch == null )
                        break;
                    else
                        ball.strafe( this.map.tile_width * ( collided_switch.state == LEFT_UP ? 1 : -1 ) );
                // Ball has collided with a switch
                case 'switch':
                    collided_switch = this.switches.find( function(i) return i.name == collided_name );

                    if ( collided_switch == null ) break;

                    if ( collided_switch.loaded() && collided_switch.ball != ball )
                        collided_switch.flip();
                    else
                    {
                        collided_switch.ball = ball;
                        ball.state = BALL_LOADED;
                    }
                // Ball has collided with a trigger
                case 'trigger':
                    collided_switch = this.switches.find( function(i) return i.name == collided_name );

                    if ( collided_switch == null )
                        break;
                    else
                        collided_switch.flip();
                case 'wall':
            }
        }
    }

    function toggle_layers( hide = false )
    {
        var end_x = 0.0;
        var end_y = 0.0;
        var i = 0;

        for ( layer in this.map.layers )
            for ( y in 0...layer.tiles.length )
                for ( x in 0...layer.tiles[y].length )
                {
                    var tilez = layer.map.visual.geometry_for_tile( layer.name, x, y );

                    if ( tilez != null )
                    {
                        for ( v in tilez.vertices )
                        {
                            if ( hide )
                            {
                                this.random_verts.push( [ v.pos.x, v.pos.y ] );
                                end_x = end_y = 0.0;
                            }
                            else
                            {
                                end_x = this.random_verts[i][0];
                                end_y = this.random_verts[i][1];
                                i += 1;
                            }

                            Actuate.tween( v.pos, 2.0, { x: end_x, y: end_y } ).ease( luxe.tween.easing.Expo.easeOut );
                        }
                    }
                }
    }

    function create_debug_text()
    {
        this.debug_text.text = "";

        for ( i in 0...this.players.count )
        {
            this.debug_text.text += 'Player ${ i + 1 } ${ ( players.get( i ).is_active ) ? '<<' : '' }\n';
            this.debug_text.text += 'Score: ${players.get( i ).score}\n';
            this.debug_text.text += 'Balls: ${players.get( i ).balls.available().length}\n';
            this.debug_text.text += '\n';
        }

        this.debug_text.text += '\nBalls moving: ${ this.players.balls.moving().length }\n';

        for ( ball in this.players.balls )
        {
            if ( !ball.is_available() && !ball.is_finished() )
                this.debug_text.text += '${ ball.state }\n';
        }
    }

    override function update( dt:Float )
    {
        if ( DEBUG_ENABLED ) create_debug_text();

        apply_input( dt );
        update_positions();

        if ( this.play_active && this.players.balls.moving().length == 0 )
        {
            trace( this.players.balls.moving().length );
            this.players.next_available();
            this.play_active = false;
        }
    }

    function update_positions()
    {
        for ( ball in this.players.balls )
        {
            if ( ball.is_available() ) continue;

            ball.sync_position();

            for ( block in this.score_blocks )
            {
                if ( ball.can_score()
                    && ball.position.x > block.pos.x
                    && ball.position.x < block.pos.x + block.width
                    && ball.position.y > block.pos.y )
                {
                    ball.score();
                    update_score( block );
                    ball.release( true );
                    break;
                }
            }
        }
    }

    function update_score( block:TiledObject )
    {
        switch ( block.type )
        {
            case 'random':
                active_player.score += Math.round( Math.random() * 25 );
        }
    }
}

class Fader extends luxe.Component
{
    var overlay:Sprite;

    override function init()
    {
        overlay = new Sprite({
            size: Luxe.screen.size,
            color: new Color( 0, 0, 0, 1 ),
            centered: false,
            depth: 99
        });
    }

    public function out( ?time = 1.0, ?fn: Void -> Void )
    {
        overlay.color.tween( time, { a: 1 } ).onComplete( fn );
    }

    public function up( ?time = 1.0, ?fn: Void -> Void)
    {
        overlay.color.tween( time, { a: 0 } ).onComplete( fn );
    }

    override function ondestroy()
    {
        overlay.destroy();
    }
}
