import Cell;
import Door;
import Pushwall;

import haxe.ds.Vector;

import luxe.Color;
import luxe.Input;
import luxe.Rectangle;
import luxe.Sprite;
import luxe.Text;
import luxe.Vector as LuxeVector;
import luxe.Visual;
import luxe.options.SpriteOptions;
import luxe.tween.Actuate;
import luxe.tween.easing.*;
import luxe.utils.Maths;

import phoenix.Batcher;
import phoenix.Camera;
import phoenix.Texture;
import phoenix.RenderTexture;

import snow.api.buffers.ArrayBufferView;
import snow.api.buffers.Uint8Array;

using Lambda;
using thx.Floats;

typedef CastValues =
{
    var dark_wall : Bool;
    var dist      : Float;
    var intercept : Float;
    var map_x     : Int;
    var map_y     : Int;
    var map_type  : String;
    var offset    : Float;
    var scale     : Float;
    var texture   : String;
}

enum GameState
{
    TITLE;
    PLAYING;
    DIED;
    ENDED;
}

class Main extends luxe.Game
{
    var active_doors            : Array<Door> = [];
    var active_movewalls        : Array<Pushwall> = [];
    var active_pushwalls        : Array<Pushwall> = [];
    var angles                  : Array<Int> = [];
    var buffer                  : Uint8Array;
    var cast_results            : Array<CastValues> = [];
    var ceiling_color           : Int;
    var ceiling_texture         : String;
    var cos_table               : Array<Float> = [];
    var default_ceiling_color   : Int;
    var default_ceiling_texture : String;
    var default_floor_color     : Int;
    var default_floor_texture   : String;
    var default_wall_texture    : String;
    var display_surface         : Sprite;
    var display_texture         : RenderTexture;
    var draw_ceiling            : Bool;
    var draw_floor              : Bool;
    var draw_textures           : Bool;
    var draw_walls              : Bool;
    var fish_eye_table          : Array<Float> = [];
    var fixed_angles            : Int;
    var fixed_factor            : Int;
    var fixed_shift             : Int;
    var fixed_step              : Float;
    var floor_color             : Int;
    var floor_texture           : String;
    var frame_rate              : Float;
    var frame_start_time        : Float;
    var frames_rendered         : Int;
    var game_state              : GameState;
    var half_fov                : Int;
    var inv_cos_table           : Array<Float> = [];
    var inv_sin_table           : Array<Float> = [];
    var inv_tan_table           : Array<Float> = [];
    var map                     : Vector<Vector<Cell>>;
    var map_columns             : Int;
    var map_doors               : Vector<Vector<Door>>;
    var map_pushwalls           : Vector<Vector<Pushwall>>;
    var map_raw                 : Array<Array<String>>;
    var map_rows                : Int;
    var map_x_size              : Int;
    var map_y_size              : Int;
    var next_x_cell             : Int;
    var next_y_cell             : Int;
    var pixels                  : Array<Int>;
    var player_angle            : Int;
    var player_fov              : Int;
    var player_move_x           : Int;
    var player_move_y           : Int;
    var player_starting_angle   : Int;
    var player_starting_x       : Int;
    var player_starting_y       : Int;
    var player_x                : Int;
    var player_y                : Int;
    var push_direction          : CellDirection;
    var push_dist               : Float;
    var push_map_cell           : Cell;
    var push_x_bound            : Int;
    var push_x_cell             : Int;
    var push_x_intercept        : Float;
    var push_y_bound            : Int;
    var push_y_cell             : Int;
    var push_y_intercept        : Float;
    var scale_factor            : Int;
    var screen_height           : Float;
    var screen_width            : Float;
    var sin_table               : Array<Float> = [];
    var tan_table               : Array<Float> = [];
    var overlay_die             : Sprite;
    var overlay_end             : Sprite;
    var overlay_title           : Sprite;
    var view_height             : Int;
    var view_pixels             : Int;
    var view_width              : Int;
    var wall_colors             : Map<String, Int>;
    var wall_texture            : String;
    var x_bound                 : Int;
    var x_delta                 : Int;
    var x_dist                  : Float;
    var x_intercept             : Float;
    var x_map_cell              : Cell;
    var x_offset                : Float;
    var x_push_dist             : Float;
    var x_push_intercept        : Float;
    var x_push_map_cell         : Cell;
    var x_push_offset           : Float;
    var x_push_x_cell           : Int;
    var x_push_y_cell           : Int;
    var x_ray_dist              : Float;
    var x_step                  : Array<Float> = [];
    var x_x_cell                : Int;
    var x_y_cell                : Int;
    var y_bound                 : Int;
    var y_delta                 : Int;
    var y_dist                  : Float;
    var y_intercept             : Float;
    var y_map_cell              : Cell;
    var y_offset                : Float;
    var y_push_dist             : Float;
    var y_push_intercept        : Float;
    var y_push_map_cell         : Cell;
    var y_push_offset           : Float;
    var y_push_x_cell           : Int;
    var y_push_y_cell           : Int;
    var y_ray_dist              : Float;
    var y_step                  : Array<Float> = [];
    var y_x_cell                : Int;
    var y_y_cell                : Int;

    var DEBUG_ENABLED    = false;

    var game_ready       = false;
    var light_band       = 32;
    var light_factor     = 6;
    var light_halo       = 32 * 4;
    var lighting_enabled = true;

    override function ready()
    {
        setup_variables();
        setup_tables();
        setup_camera();
        setup_map();
        setup_input();
        setup_overlays();
        activate_movewalls();

        this.game_ready = true;
        this.game_state = GameState.TITLE;

        show_title();
    }

    function activate_movewalls()
    {
        if ( this.active_movewalls.length == 0 ) return;

        for ( movewall in this.active_movewalls )
        {
            movewall.activate( movewall.direction );
        }
    }

    function apply_input( dt:Float )
    {
        var movement_step = Std.int( 128 * dt );
        var turn_step     = Std.int( this.angles[ 60 ] * dt );

        if ( Luxe.input.inputdown( 'activate_object' ) )
        {
            var move_x = Std.int( this.cos_table[ this.player_angle ] * Cell.WIDTH );
            var move_y = Std.int( this.sin_table[ this.player_angle ] * Cell.HEIGHT );
            var x_cell = Std.int( ( this.player_x + move_x ) / Cell.WIDTH );
            var y_cell = Std.int( ( this.player_y + move_y ) / Cell.HEIGHT );

            if ( this.map_doors[ y_cell ][ x_cell ] != null )
            {
                switch ( this.map_doors[ y_cell ][ x_cell ].state )
                {
                    case DoorState.CLOSED:
                        this.map_doors[ y_cell ][ x_cell ].state = DoorState.OPENING;
                        this.active_doors.push( this.map_doors[ y_cell ][ x_cell ] );
                    case DoorState.OPEN:
                        this.map_doors[ y_cell ][ x_cell ].state = DoorState.CLOSING;
                    default:
                        // Silence the freakin' "unmatched patterns" compiler error
                }
            }
            else if ( this.map_pushwalls[ y_cell ][ x_cell ] != null )
            {
                var push_direction = null;

                switch ( this.map_pushwalls[ y_cell ][ x_cell ].type )
                {
                    case PushwallType.PUSH:
                        if ( Math.abs( move_x ) > Math.abs( move_y ) )
                        {
                            if ( this.player_angle >= this.angles[ 90 ] && this.player_angle < this.angles[ 270 ] )
                                push_direction = CellDirection.MOVING_EAST;
                            else
                                push_direction = CellDirection.MOVING_WEST;
                        }
                        else
                        {
                            if ( this.player_angle >= this.angles[ 0 ] && this.player_angle < this.angles[ 180 ] )
                                push_direction = CellDirection.MOVING_SOUTH;
                            else if ( this.player_angle >= this.angles[ 180 ] && this.player_angle < this.angles[ 360 ] )
                                push_direction = CellDirection.MOVING_NORTH;
                        }

                        if ( this.map_pushwalls[ y_cell ][ x_cell ].activate( push_direction ) )
                        {
                            this.active_pushwalls.push( this.map_pushwalls[ y_cell ][ x_cell ] );
                        }
                    default:
                        // Silence the freakin' "unmatched patterns" compiler error
                }
            }
        }

        if ( Luxe.input.inputdown( 'move_forward' ) )
        {
            this.player_move_x = Std.int( Math.round( this.cos_table[ this.player_angle ] * movement_step ) );
            this.player_move_y = Std.int( Math.round( this.sin_table[ this.player_angle ] * movement_step ) );
        }

        if ( Luxe.input.inputdown( 'move_left' ) )
        {
            this.player_move_x = Std.int( Math.round( this.cos_table[ ( this.player_angle - this.angles[ 90 ] + this.angles[ 360 ] ) % this.angles[ 360 ] ] * movement_step ) );
            this.player_move_y = Std.int( Math.round( this.sin_table[ ( this.player_angle - this.angles[ 90 ] + this.angles[ 360 ] ) % this.angles[ 360 ] ] * movement_step ) );
        }

        if ( Luxe.input.inputdown( 'move_backward' ) )
        {
            this.player_move_x = -Std.int( Math.round( this.cos_table[ this.player_angle ] * movement_step ) );
            this.player_move_y = -Std.int( Math.round( this.sin_table[ this.player_angle ] * movement_step ) );
        }

        if ( Luxe.input.inputdown( 'move_right' ) )
        {
            this.player_move_x = Std.int( Math.round( this.cos_table[ ( this.player_angle + this.angles[ 90 ] ) % this.angles[ 360 ] ] * movement_step ) );
            this.player_move_y = Std.int( Math.round( this.sin_table[ ( this.player_angle + this.angles[ 90 ] ) % this.angles[ 360 ] ] * movement_step ) );
        }

        if ( Luxe.input.inputdown( 'turn_left' ) )
        {
            this.player_angle = ( this.player_angle - turn_step + this.angles[ 360 ] ) % this.angles[ 360 ];
        }

        if ( Luxe.input.inputdown( 'turn_right' ) )
        {
            this.player_angle = ( this.player_angle + turn_step ) % this.angles[ 360 ];
        }
    }

    function cast_x_ray( x_start:Float, y_start:Float, angle:Int )
    {
        this.x_offset      = 0;
        this.x_push_dist   = 1e+8;
        this.x_push_offset = 0;
        this.x_ray_dist    = 0;
        this.x_x_cell      = 0;
        this.x_y_cell      = 0;

        // Abort the cast if the next Y step sends us out of bounds.
        //
        if ( Math.abs( this.y_step[ angle ] ) == 0 )
        {
            return 1e+8;
        }

        if ( angle < this.angles[ 90 ] || angle >= this.angles[ 270 ] )
        {
            // Configure our cast for the right half of the map.
            //
            this.x_bound = Cell.WIDTH + Cell.WIDTH * Std.int( x_start / Cell.WIDTH );
            this.x_delta = Cell.WIDTH;
            this.y_intercept = this.tan_table[ angle ] * ( this.x_bound - x_start ) + y_start;
            this.next_x_cell = 0;
        }
        else
        {
            // Configure our cast for the left half of the map.
            //
            this.x_bound = Cell.WIDTH * Std.int( x_start / Cell.WIDTH );
            this.x_delta = -Cell.WIDTH;
            this.y_intercept = this.tan_table[ angle ] * ( this.x_bound - x_start ) + y_start;
            this.next_x_cell = -1;
        }

        // Check to see if we have any visible pushwalls in our ray's path.
        //
        for ( pushwall in this.active_movewalls.concat( this.active_pushwalls ) )
        {
            switch ( pushwall.direction )
            {
                case CellDirection.MOVING_EAST, CellDirection.MOVING_WEST:
                    // The wall is moving in one the directions we can work with.
                default:
                    continue;
            }

            if ( angle >= this.angles[ 90 ] && angle < this.angles[ 270 ] )
            {
                this.push_x_bound = Std.int( pushwall.right );
                if ( this.push_x_bound > x_start ) continue;
            }
            else
            {
                this.push_x_bound = Std.int( pushwall.left );
                if ( this.push_x_bound < x_start ) continue;
            }

            this.push_y_intercept = this.tan_table[ angle ] * ( this.push_x_bound - x_start ) + y_start;
            this.push_x_cell = Std.int( this.push_x_bound / Cell.WIDTH );
            this.push_y_cell = Std.int( this.push_y_intercept / Cell.HEIGHT );

            if ( this.push_x_cell >= 0 && this.push_x_cell <= this.map_columns - 1
                && this.push_y_cell >= 0 && this.push_y_cell <= this.map_rows - 1 )
                this.push_map_cell = this.map[ this.push_y_cell ][ this.push_x_cell ];
            else
                continue;

            if ( this.push_map_cell.value == Cell.SECRET_CELL
                && ( pushwall.x_cell == this.push_x_cell || pushwall.to_x_cell == this.push_x_cell )
                && ( pushwall.y_cell == this.push_y_cell || pushwall.to_y_cell == this.push_y_cell ) )
            {
                this.push_dist = ( this.push_y_intercept - y_start ) * this.inv_sin_table[ angle ];

                if ( this.push_dist < this.x_push_dist )
                {
                    this.x_push_dist = this.push_dist;
                    this.x_push_intercept = this.push_y_intercept;
                    this.x_push_x_cell = this.push_x_cell;
                    this.x_push_y_cell = this.push_y_cell;
                    this.x_push_map_cell = this.push_map_cell;
                }
            }
        }

        while ( true )
        {
            // Calculate the next X and Y cells hit by our casted ray,
            // and see if they fall within our map's boundaries.
            //
            this.x_x_cell = Std.int( ( this.x_bound + this.next_x_cell ) / Cell.WIDTH );
            this.x_y_cell = Std.int( this.y_intercept / Cell.HEIGHT );

            if ( this.x_x_cell >= 0 && this.x_x_cell <= this.map_columns - 1
                && this.x_y_cell >= 0 && this.x_y_cell <= this.map_rows - 1 )
            {
                this.x_map_cell = this.map[ this.x_y_cell ][ this.x_x_cell ];
            }
            else
            {
                this.x_intercept = 1e+8;
                break;
            }

            // Check the map cell at the intersected coordinates.
            //
            switch ( this.x_map_cell.value )
            {
                case Cell.END_CELL:
                    break;
                case Cell.DOOR_CELL:
                    this.y_intercept += ( this.y_step[ angle ] / 2 );

                    if ( this.x_map_cell.offset < ( this.y_intercept % Cell.HEIGHT ) )
                    {
                        this.x_offset = this.x_map_cell.offset;
                        break;
                    }
                case Cell.SECRET_CELL:
                    var pushwall = this.map_pushwalls[ this.x_y_cell ][ this.x_x_cell ];

                    switch ( pushwall.state )
                    {
                        case PushwallState.MOVING:
                            switch ( pushwall.direction )
                            {
                                case CellDirection.MOVING_NORTH, CellDirection.MOVING_SOUTH:
                                    if ( this.x_map_cell.offset >= 0 && ( this.y_intercept % Cell.HEIGHT ) > this.x_map_cell.offset - 1 )
                                    {
                                        this.x_offset = this.x_map_cell.offset;
                                        break;
                                    }
                                    else if ( this.x_map_cell.offset < 0 && ( this.y_intercept % Cell.HEIGHT ) < ( Cell.WIDTH + this.x_map_cell.offset ) )
                                    {
                                        this.x_offset = this.x_map_cell.offset;
                                        break;
                                    }
                                case CellDirection.MOVING_EAST, CellDirection.MOVING_WEST:
                                    if ( this.x_map_cell.offset >= -1 && this.x_map_cell.offset <= 1 )
                                    {
                                        break;
                                    }
                            }
                        case PushwallState.STOPPED, PushwallState.FINISHED:
                        {
                            break;
                        }
                    }
                case Cell.BOUND_CELL, Cell.WALL_CELL:
                    break;
            }

            this.y_intercept += this.y_step[ angle ];
            this.x_bound += this.x_delta;
        }

        if ( this.y_intercept == 1e+8 )
            this.x_ray_dist = 1e+8;
        else
            this.x_ray_dist = ( this.y_intercept - y_start ) * this.inv_sin_table[ angle ];

        if ( this.x_push_dist < this.x_ray_dist )
        {
            this.y_intercept = this.x_push_intercept;
            this.x_map_cell = this.x_push_map_cell;
            this.x_offset = this.x_push_offset;
            this.x_x_cell = this.x_push_x_cell;
            this.x_y_cell = this.x_push_y_cell;

            return this.x_push_dist;
        }
        else
            return this.x_ray_dist;
    }

    function cast_y_ray( x_start:Float, y_start:Float, angle:Int )
    {
        this.y_offset      = 0;
        this.y_push_dist   = 1e+8;
        this.y_push_offset = 0;
        this.y_ray_dist    = 0;
        this.y_x_cell      = 0;
        this.y_y_cell      = 0;

        // Abort the cast if the next X step sends us out of bounds.
        //
        if ( Math.abs( this.x_step[ angle ] ) == 0 )
        {
            return 1e+8;
        }

        if ( angle >= this.angles[ 0 ] && angle < this.angles[ 180 ] )
        {
            // Configure our cast for the lower half of the map.
            //
            this.y_bound = Cell.HEIGHT + Cell.HEIGHT * Std.int( y_start / Cell.HEIGHT );
            this.y_delta = Cell.HEIGHT;
            this.x_intercept = this.inv_tan_table[ angle ] * ( this.y_bound - y_start ) + x_start;
            this.next_y_cell = 0;
        }
        else
        {
            // Configure our cast for the upper half of the map.
            //
            this.y_bound = Cell.HEIGHT * Std.int( y_start / Cell.HEIGHT );
            this.y_delta = -Cell.HEIGHT;
            this.x_intercept = this.inv_tan_table[ angle ] * ( this.y_bound - y_start ) + x_start;
            this.next_y_cell = -1;
        }

        // Check to see if we have any visible pushwalls in our ray's path.
        //
        for ( pushwall in this.active_movewalls.concat( this.active_pushwalls ) )
        {
            switch ( pushwall.direction )
            {
                case CellDirection.MOVING_NORTH, CellDirection.MOVING_SOUTH:
                    // The wall is moving in one the directions we can work with.
                default:
                    continue;
            }

            if ( angle >= this.angles[ 0 ] && angle < this.angles[ 180 ] )
            {
                this.push_y_bound = Std.int( pushwall.top );
                if ( this.push_y_bound < y_start ) continue;
            }
            else
            {
                this.push_y_bound = Std.int( pushwall.bottom );
                if ( this.push_y_bound > y_start ) continue;
            }

            this.push_x_intercept = this.inv_tan_table[ angle ] * ( this.push_y_bound - y_start ) + x_start;
            this.push_x_cell = Std.int( this.push_x_intercept / Cell.WIDTH );
            this.push_y_cell = Std.int( this.push_y_bound / Cell.HEIGHT );

            if ( this.push_x_cell >= 0 && this.push_x_cell <= this.map_columns - 1
                && this.push_y_cell >= 0 && this.push_y_cell <= this.map_rows - 1 )
                this.push_map_cell = this.map[ this.push_y_cell ][ this.push_x_cell ];
            else
                continue;

            if ( this.push_map_cell.value == Cell.SECRET_CELL
                && ( pushwall.x_cell == this.push_x_cell || pushwall.to_x_cell == this.push_x_cell )
                && ( pushwall.y_cell == this.push_y_cell || pushwall.to_y_cell == this.push_y_cell ) )
            {
                this.push_dist = ( this.push_x_intercept - x_start ) * this.inv_cos_table[ angle ];

                if ( this.push_dist < this.y_push_dist )
                {
                    this.y_push_dist = this.push_dist;
                    this.y_push_intercept = this.push_x_intercept;
                    this.y_push_x_cell = this.push_x_cell;
                    this.y_push_y_cell = this.push_y_cell;
                    this.y_push_map_cell = this.push_map_cell;
                }
            }
        }

        while ( true )
        {
            // Calculate the next X and Y cells hit by our casted ray,
            // and see if they fall within our map's boundaries.
            //
            this.y_x_cell = Std.int( this.x_intercept / Cell.WIDTH );
            this.y_y_cell = Std.int( ( this.y_bound + this.next_y_cell ) / Cell.HEIGHT );

            if ( this.y_x_cell >= 0 && this.y_x_cell <= this.map_columns - 1
                 && this.y_y_cell >= 0 && this.y_y_cell <= this.map_rows - 1 )
            {
                this.y_map_cell = this.map[ this.y_y_cell ][ this.y_x_cell ];
            }
            else
            {
                this.x_intercept = 1e+8;
                break;
            }

            // Check the map cell at the intersected coordinates.
            //
            switch ( this.y_map_cell.value )
            {
                case Cell.END_CELL:
                    break;
                case Cell.DOOR_CELL:
                    this.x_intercept += ( this.x_step[ angle ] / 2 );

                    if ( this.y_map_cell.offset < ( this.x_intercept % Cell.WIDTH ) )
                    {
                        this.y_offset = this.y_map_cell.offset;
                        break;
                    }
                case Cell.SECRET_CELL:
                    var pushwall = this.map_pushwalls[ this.y_y_cell ][ this.y_x_cell ];

                    switch ( pushwall.state )
                    {
                        case PushwallState.MOVING:
                            switch ( pushwall.direction )
                            {
                                case CellDirection.MOVING_EAST, CellDirection.MOVING_WEST:
                                    if ( this.y_map_cell.offset >= 0 && ( this.x_intercept % Cell.WIDTH ) > this.y_map_cell.offset - 1 )
                                    {
                                        this.y_offset = this.y_map_cell.offset;
                                        break;
                                    }
                                    else if ( this.y_map_cell.offset < 0 && ( this.x_intercept % Cell.WIDTH ) < ( Cell.WIDTH + this.y_map_cell.offset ) )
                                    {
                                        this.y_offset = this.y_map_cell.offset;
                                        break;
                                    }
                                case CellDirection.MOVING_NORTH, CellDirection.MOVING_SOUTH:
                                    if ( this.y_map_cell.offset >= -1 && this.y_map_cell.offset <= 1 )
                                    {
                                        break;
                                    }
                            }
                        case PushwallState.STOPPED, PushwallState.FINISHED:
                            break;
                    }
                case Cell.BOUND_CELL, Cell.WALL_CELL:
                    break;
            }

            this.x_intercept += this.x_step[ angle ];
            this.y_bound += this.y_delta;
        }

        if ( this.x_intercept == 1e+8 )
            this.y_ray_dist = 1e+8;
        else
            this.y_ray_dist = ( this.x_intercept - x_start ) * this.inv_cos_table[ angle ];

        if ( this.y_push_dist < this.y_ray_dist )
        {
            this.x_intercept = this.y_push_intercept;
            this.y_map_cell = this.y_push_map_cell;
            this.y_offset = this.y_push_offset;
            this.y_x_cell = this.y_push_x_cell;
            this.y_y_cell = this.y_push_y_cell;

            return this.y_push_dist;
        }
        else
            return this.y_ray_dist;
    }

    function check_collisions()
    {
        var x_cell = Std.int( this.player_x / Cell.WIDTH );
        var y_cell = Std.int( this.player_y / Cell.HEIGHT );
        var x_sub_cell = this.player_x % Cell.WIDTH;
        var y_sub_cell = this.player_y % Cell.HEIGHT;
        var map_cell = this.map[ 0 ][ 0 ];
        var door_cell = this.map_doors[ 0 ][ 0 ];
        var push_cell = this.map_pushwalls[ 0 ][ 0 ];
        var push_pos = 0.0;

        if ( this.player_move_x == 0 && this.player_move_y == 0 )
        {
            map_cell = this.map[ y_cell ][ x_cell + 1 ];
            door_cell = this.map_doors[ y_cell ][ x_cell + 1 ];
            push_cell = this.map_pushwalls[ y_cell ][ x_cell + 1 ];

            if ( push_cell != null
                && push_cell.direction == CellDirection.MOVING_EAST
                && this.player_x >= ( Std.int( push_cell.left ) - ( Cell.WIDTH - Cell.MARGIN ) ) )
            {
                this.player_move_x = Std.int( push_cell.left ) - ( Cell.WIDTH - Cell.MARGIN ) - this.player_x;
                push_pos = push_cell.left;
            }

            map_cell = this.map[ y_cell ][ x_cell - 1 ];
            door_cell = this.map_doors[ y_cell ][ x_cell - 1 ];
            push_cell = this.map_pushwalls[ y_cell ][ x_cell - 1 ];

            if ( push_cell != null
                && push_cell.direction == CellDirection.MOVING_WEST
                && this.player_x <= Std.int( push_cell.right ) + Cell.MARGIN )
            {
                this.player_move_x = Std.int( push_cell.right ) + Cell.MARGIN - this.player_x;
                push_pos = push_cell.right;
            }

            map_cell = this.map[ y_cell + 1 ][ x_cell ];
            door_cell = this.map_doors[ y_cell + 1 ][ x_cell ];
            push_cell = this.map_pushwalls[ y_cell + 1 ][ x_cell ];

            if ( push_cell != null
                && push_cell.direction == CellDirection.MOVING_NORTH
                && this.player_y >= ( Std.int( push_cell.top ) - ( Cell.HEIGHT - Cell.MARGIN ) ) )
            {
                this.player_move_y = Std.int( push_cell.top ) - ( Cell.HEIGHT - Cell.MARGIN ) - this.player_y;
                push_pos = push_cell.top;
            }

            map_cell = this.map[ y_cell - 1 ][ x_cell ];
            door_cell = this.map_doors[ y_cell - 1 ][ x_cell ];
            push_cell = this.map_pushwalls[ y_cell - 1 ][ x_cell ];

            if ( push_cell != null
                && push_cell.direction == CellDirection.MOVING_SOUTH
                && this.player_y <= ( Std.int( push_cell.bottom ) + Cell.MARGIN ) )
            {
                this.player_move_y = Std.int( push_cell.bottom ) + Cell.MARGIN - this.player_y;
                push_pos = push_cell.bottom;
            }
        }

        // Check for collisions while player is moving west
        //
        if ( this.player_move_x > 0 )
        {
            map_cell = this.map[ y_cell ][ x_cell + 1 ];
            door_cell = this.map_doors[ y_cell ][ x_cell + 1 ];
            push_cell = this.map_pushwalls[ y_cell ][ x_cell + 1 ];

            if ( map_cell.value == Cell.EMPTY_CELL )
            {
                // Let the player keep on walkin'...
            }
            else if ( map_cell.value == Cell.END_CELL )
            {
                player_paroled();
            }
            else if ( map_cell.value == Cell.DOOR_CELL && door_cell.state == DoorState.OPEN )
            {
                // Let the player pass through the open door...
            }
            else if ( push_cell != null && push_cell.state == PushwallState.MOVING )
            {
                if ( this.player_x >= ( Std.int( push_cell.left ) - ( Cell.WIDTH - Cell.MARGIN ) ) )
                {
                    this.player_move_x = Std.int( push_cell.left ) - ( Cell.WIDTH - Cell.MARGIN ) - this.player_x;
                }
            }
            else if ( x_sub_cell >= ( Cell.WIDTH - Cell.MARGIN ) )
            {
                if ( push_pos > 0 && push_pos >= this.player_x )
                    player_squished();
                else
                    this.player_move_x = -( x_sub_cell - ( Cell.WIDTH - Cell.MARGIN ) );
            }
        }

        // Check for collisions while player is moving east
        //
        else if ( this.player_move_x < 0 )
        {
            map_cell = this.map[ y_cell ][ x_cell - 1 ];
            door_cell = this.map_doors[ y_cell ][ x_cell - 1 ];
            push_cell = this.map_pushwalls[ y_cell ][ x_cell - 1 ];

            if ( map_cell.value == Cell.EMPTY_CELL )
            {
                // Let the player keep on walkin'...
            }
            else if ( map_cell.value == Cell.END_CELL )
            {
                player_paroled();
            }
            else if ( map_cell.value == Cell.DOOR_CELL && door_cell.state == DoorState.OPEN )
            {
                // Let the player pass through the open door...
            }
            else if ( push_cell != null && push_cell.state == PushwallState.MOVING )
            {
                if ( this.player_x <= ( Std.int( push_cell.right ) + Cell.MARGIN ) )
                {
                    this.player_move_x = Std.int( push_cell.right ) + Cell.MARGIN - this.player_x;
                }
            }
            else if ( x_sub_cell <= Cell.MARGIN )
            {
                if ( push_pos > 0 && push_pos <= this.player_x )
                    player_squished();
                else
                    this.player_move_x = Cell.MARGIN - x_sub_cell;
            }
        }

        // Check for collisions while player is moving south
        //
        if ( this.player_move_y > 0 )
        {
            map_cell = this.map[ y_cell + 1 ][ x_cell ];
            door_cell = this.map_doors[ y_cell + 1 ][ x_cell ];
            push_cell = this.map_pushwalls[ y_cell + 1 ][ x_cell ];

            if ( map_cell.value == Cell.EMPTY_CELL )
            {
                // Let the player keep on walkin'...
            }
            else if ( map_cell.value == Cell.END_CELL )
            {
                player_paroled();
            }
            else if ( map_cell.value == Cell.DOOR_CELL && door_cell.state == DoorState.OPEN )
            {
                // Let the player pass through the open door...
            }
            else if ( map_cell.value == Cell.SECRET_CELL && push_cell.state == PushwallState.MOVING )
            {
                if ( this.player_y >= ( Std.int( push_cell.top ) - ( Cell.HEIGHT - Cell.MARGIN ) ) )
                {
                    this.player_move_y = Std.int( push_cell.top ) - ( Cell.HEIGHT - Cell.MARGIN ) - this.player_y;
                }
            }
            else if ( y_sub_cell >= ( Cell.HEIGHT - Cell.MARGIN ) )
            {
                if ( push_pos > 0 && push_pos <= this.player_y )
                    player_squished();
                else
                    this.player_move_y = -( y_sub_cell - ( Cell.HEIGHT - Cell.MARGIN ) );
            }
        }

        // Check for collisions while player is moving north
        //
        else if ( this.player_move_y < 0 )
        {
            map_cell = this.map[ y_cell - 1 ][ x_cell ];
            door_cell = this.map_doors[ y_cell - 1 ][ x_cell ];
            push_cell = this.map_pushwalls[ y_cell - 1 ][ x_cell ];

            if ( map_cell.value == Cell.EMPTY_CELL )
            {
                // Let the player keep on walkin'...
            }
            else if ( map_cell.value == Cell.END_CELL )
            {
                player_paroled();
            }
            else if ( map_cell.value == Cell.DOOR_CELL && door_cell.state == DoorState.OPEN )
            {
                // Let the player pass through the open door...
            }
            else if ( map_cell.value == Cell.SECRET_CELL && push_cell.state == PushwallState.MOVING )
            {
                if ( this.player_y <= ( Std.int( push_cell.bottom ) + Cell.MARGIN ) )
                {
                    this.player_move_y = Std.int( push_cell.bottom ) + Cell.MARGIN - this.player_y;
                }
            }
            else if ( y_sub_cell <= Cell.MARGIN )
            {
                if ( push_pos > 0 && push_pos >= this.player_y )
                    player_squished();
                else
                    this.player_move_y = Cell.MARGIN - y_sub_cell;
            }
        }

        this.player_x = Std.int( ( this.player_x + this.player_move_x ).clamp( Cell.WIDTH,  this.map_x_size - Cell.WIDTH ) );
        this.player_y = Std.int( ( this.player_y + this.player_move_y ).clamp( Cell.HEIGHT, this.map_y_size - Cell.HEIGHT ) );

        this.player_move_x = 0;
        this.player_move_y = 0;
    }

    function clear_buffer()
    {
        var color = 0x0;
        var ry    = 0;
        var yx    = 0;

        for ( x in 0...this.view_width )
        {
            for ( y in 0...this.view_height )
            {
                ry = this.view_height - y - 1;
                yx = ( x * 4 ) + ( ry * this.view_width * 4 );

                if ( y <= this.view_height / 2 )
                    color = this.ceiling_color;
                else
                    color = this.floor_color;

                this.pixels[ yx + 0 ] = color >> 16 & 255;
                this.pixels[ yx + 1 ] = color >> 8 & 255;
                this.pixels[ yx + 2 ] = color & 255;
                this.pixels[ yx + 3 ] = 255;
            }
        }
    }

    override function config( config:luxe.AppConfig )
    {
        config.preload.textures.push({ id: 'assets/died.jpg' });
        config.preload.textures.push({ id: 'assets/end.jpg' });
        config.preload.textures.push({ id: 'assets/title.jpg' });

        // TODO: Refactor/disable this for desktop targets
        //
        config.runtime.prevent_default_keys.push( Key.space );

        return config;
    }

    function draw_buffer()
    {
        this.buffer.set( this.pixels );
        this.display_texture.submit( this.buffer );
    }

    function hide_checkout()
    {
        this.overlay_die.color.tween( 1.0, { a: 0 });
    }

    function hide_parole()
    {
        this.overlay_end.color.tween( 1.0, { a: 0 });
    }

    function hide_title()
    {
        this.overlay_title.color.tween( 1.0, { a: 0 });
    }

    override function onkeyup( e:KeyEvent )
    {
        switch ( this.game_state )
        {
            case GameState.TITLE:
                hide_title();
                this.game_state = GameState.PLAYING;
            case GameState.PLAYING:
                switch ( e.keycode )
                {
                    case Key.minus, Key.kp_minus:
                        if ( this.DEBUG_ENABLED ) this.light_factor *= 2;
                    case Key.plus, Key.kp_plus:
                        if ( this.DEBUG_ENABLED ) this.light_factor = Std.int( this.light_factor / 2 );
                    case Key.key_1:
                        if ( this.DEBUG_ENABLED ) this.lighting_enabled = !this.lighting_enabled;
                }
            default:
                // Silence the freakin' "unmatched patterns" compiler error
        }
    }

    override function onmouseup( e:MouseEvent )
    {
        switch ( this.game_state )
        {
            case GameState.TITLE:
                hide_title();
                this.game_state = GameState.PLAYING;
            default:
                // Silence the freakin' "unmatched patterns" compiler error
        }
    }

    function player_paroled()
    {
        this.game_state = GameState.ENDED;
        show_parole();
    }

    function player_squished()
    {
        this.game_state = GameState.DIED;
        show_checkout();
    }

    function populate_buffer()
    {
        var half_height = 0;
        var pixel_alpha = 255;
        var pixel_blue  = 0;
        var pixel_green = 0;
        var pixel_red   = 0;
        var real_y      = 0;
        var wall_bottom = 0;
        var wall_color  = 0x0;
        var wall_height = 0;
        var wall_light  = 0;
        var wall_top    = 0;
        var wall_x      = 0;
        var wall_y      = 0;

        for ( ray in this.cast_results )
        {
            if ( ray == null )
                continue;
            else
                wall_x += 1;

            wall_height = Std.int( ( Std.int( ray.scale ) >> 1 << 1 ).clamp ( 0, this.view_height ) );
            half_height = Std.int( wall_height / 2 );
            wall_top    = Std.int( ( this.view_height / 2 ) - half_height );
            wall_bottom = Std.int( ( this.view_height / 2 ) + half_height );
            wall_color  = this.wall_colors[ ray.texture ];

            if ( this.lighting_enabled )
            {
                if ( ray.dist > 0 )
                    wall_light = Std.int( ( -this.light_halo + ray.dist ) / this.light_band ) * this.light_factor;
                else
                    wall_light = 0;
            }

            for ( y in wall_top...wall_bottom )
            {
                real_y = this.view_height - y - 1;
                wall_y = ( wall_x * 4 ) + ( real_y * this.view_width * 4 );

                pixel_red   = Std.int( ( ( wall_color >> 16 & 255 ) - wall_light ).clamp( 0, 255 ) );
                pixel_green = Std.int( ( ( wall_color >> 8 & 255 ) - wall_light ).clamp( 0, 255 ) );
                pixel_blue  = Std.int( ( ( wall_color & 255 ) - wall_light ).clamp( 0, 255 ) );

                this.pixels[ wall_y + 0 ] = pixel_red;
                this.pixels[ wall_y + 1 ] = pixel_green;
                this.pixels[ wall_y + 2 ] = pixel_blue;
                this.pixels[ wall_y + 3 ] = pixel_alpha;
            }
        }
    }

    function setup_camera()
    {
        Luxe.renderer.clear_color.rgb( 0x000000 );
        Luxe.camera.size = new LuxeVector( this.screen_width, this.screen_height );

        this.display_texture = new RenderTexture({
            id: 'rtt',
            width: this.view_width,
            height: this.view_height
        });

        this.display_surface = new Sprite({
            texture: this.display_texture,
            size: new LuxeVector( this.screen_width, this.screen_height ),
            pos: Luxe.screen.mid
        });

        this.pixels = new Vector( this.view_pixels * 4 ).toArray();
        this.buffer = new Uint8Array( this.pixels );
        this.display_texture.submit( this.buffer );
    }

    function setup_input()
    {
        Luxe.input.bind_key( 'activate_object', Key.space );
        Luxe.input.bind_key(    'move_forward', Key.key_w );
        Luxe.input.bind_key(       'move_left', Key.key_a );
        Luxe.input.bind_key(   'move_backward', Key.key_s );
        Luxe.input.bind_key(      'move_right', Key.key_d );
        Luxe.input.bind_key(       'turn_left', Key.key_k );
        Luxe.input.bind_key(       'turn_left', Key.left );
        Luxe.input.bind_key(      'turn_right', Key.key_l );
        Luxe.input.bind_key(      'turn_right', Key.right );
    }

    function setup_map()
    {
        var cell_direction = "";
        var cell_modifier = "";
        var cell_texture = "";
        var cell_type = "";
        var cell_value = "";
        var push_direction = null;

        this.map_raw =
        [
            "W3 W3 B5 B5 W5 W5 W5 W9 W9 W9 W5 W5 W5".split( " " ),
            "W3 .. W3 W3 B3 W3 W4 W9 EE W9 W4 W5 W5".split( " " ),
            "W3 .. W3 W3 W3 W3 W4 W9 .. W9 W4 W5 W5".split( " " ),
            "W3 .. W3 W2 W4 .. W4 .. .. .. W4 W5 W5".split( " " ),
            "W3 .. ^3 ^2 ^4 .. B4 >3 W3 W3 B4 W5 W5".split( " " ),
            "W3 W3 B3 B3 B3 .. B4 >2 W2 W2 W4 B4 W5".split( " " ),
            "W3 W3 W3 W3 W3 .. B4 >4 W4 W4 W4 W4 B5".split( " " ),
            "W5 W5 W3 .. .. .. W4 .. .. W4 W4 W5 W5".split( " " ),
            "W5 W5 .. .. .. W4 W4 .. .. .. W3 W5 W5".split( " " ),
            "W5 .. .. B4 W4 W4 W4 .. .. .. W4 W5 W5".split( " " ),
            "W5 .. B4 W4 W4 W4 W4 W4 W4 .. .. W5 W5".split( " " ),
            "W5 .. W4 W4 W4 W4 B4 W2 W2 W2 <2 B5 W5".split( " " ),
            "W5 .. W4 W4 .. W4 W4 B4 W4 W4 <4 B5 W5".split( " " ),
            "W5 .. ^4 ^4 .. .. W3 W3 W4 .. .. W5 W5".split( " " ),
            "W5 W2 B2 B2 .. .. W2 W3 .. .. W4 W5 W5".split( " " ),
            "W5 W3 W3 W3 B3 .. W4 .. .. W2 W4 W5 W5".split( " " ),
            "W5 B3 W3 W3 W3 .. B3 >3 W3 W3 B3 W5 W5".split( " " ),
            "W5 .. .. W3 W3 .. W2 .. .. W2 W3 W5 W5".split( " " ),
            "W5 .. .. .. ^3 .. W3 .. .. .. W3 W5 W5".split( " " ),
            "W2 P3 W4 W4 B4 W2 W2 .. .. .. W2 W5 W5".split( " " ),
            "W2 .. W4 W4 W4 W2 W2 .. B2 W3 W2 W5 W5".split( " " ),
            "W2 .. .. W4 W4 W2 W2 .. .. W3 W2 W5 W5".split( " " ),
            "W2 .. .. .. W4 B2 W2 .. .. .. W2 W5 W5".split( " " ),
            "W2 W4 .. W4 W4 .. W2 W2 P3 W2 W2 W5 W5".split( " " ),
            "W3 .. .. .. .. .. W2 W2 .. W2 W2 W2 W2".split( " " ),
            "W3 W3 W2 W2 W3 P3 W2 .. .. .. W2 W2 W5".split( " " ),
            "W2 W2 W3 B2 .. .. P3 .. .. .. P3 .. B5".split( " " ),
            "W2 W2 .. .. W3 P3 W2 .. .. .. W2 W2 W5".split( " " ),
            "W2 .. .. .. W3 .. W2 .. .. .. W2 W5 W5".split( " " ),
            "B2 .. .. .. P2 .. W2 W1 .. W1 W2 W5 W5".split( " " ),
            "W3 W3 .. .. W3 .. W2 W1 S^ W1 W2 W5 W5".split( " " ),
            "W3 W3 W2 W2 W2 B3 W2 W1 W1 W1 W2 W5 W5".split( " " )
        ];

        this.map_rows = this.map_raw.length;
        this.map_columns = this.map_raw[ 0 ].length;
        this.map_x_size = this.map_columns * Cell.WIDTH;
        this.map_y_size = this.map_rows * Cell.HEIGHT;

        this.map = new Vector( this.map_rows );
        this.map_doors = new Vector( this.map_rows );
        this.map_pushwalls = new Vector( this.map_rows );

        this.active_movewalls = [];

        for ( y in 0...this.map_rows )
        {
            this.map[ y ] = new Vector( this.map_columns );
            this.map_doors[ y ] = new Vector( this.map_columns );
            this.map_pushwalls[ y ] = new Vector( this.map_columns );
        }
 
        for ( y in 0...this.map_rows )
        {
            for ( x in 0...this.map_columns )
            {
                cell_type = this.map_raw[ y ][ x ].charAt( 0 );
                cell_modifier = this.map_raw[ y ][ x ].charAt( 1 );

                if ( Cell.DOOR_TYPES.indexOf( cell_type ) != -1 )
                {
                    cell_value = Cell.DOOR_CELL;
                    cell_texture = Cell.DOOR_CELL;

                    this.map_doors[ y ][ x ] = new Door({
                        map: this.map,
                        parent: this.map_doors,
                        x_cell: x,
                        y_cell: y
                    });
                }
                else if ( cell_type == Cell.PLAYER_CELL )
                {
                    cell_value = Cell.EMPTY_CELL;
                    cell_texture = null;

                    switch ( cell_modifier )
                    {
                        case Cell.PLAYER_UP:
                            this.player_starting_angle = this.angles[ 270 ];
                        case Cell.PLAYER_DOWN:
                            this.player_starting_angle = this.angles[ 90 ];
                        case Cell.PLAYER_LEFT:
                            this.player_starting_angle = this.angles[ 180 ];
                        case Cell.PLAYER_RIGHT:
                            this.player_starting_angle = this.angles[ 0 ];
                    }

                    this.player_starting_x = Std.int( x * Cell.WIDTH + ( Cell.WIDTH / 2 ) );
                    this.player_starting_y = Std.int( y * Cell.HEIGHT + ( Cell.HEIGHT / 2 ) );
                }
                else if ( [ Cell.MOVE_CELL, Cell.MOVE_EAST, Cell.MOVE_NORTH,
                            Cell.MOVE_SOUTH, Cell.MOVE_WEST ].indexOf( cell_type ) != -1 )
                {
                    if ( cell_type == Cell.MOVE_CELL )
                    {
                        cell_value = Cell.SECRET_CELL;
                        cell_texture = Cell.MOVE_TEXTURES[ Std.int( Math.random() * 4 ) ];
                        cell_direction = cell_modifier;
                    }
                    else
                    {
                        cell_value = Cell.SECRET_CELL;
                        cell_texture = cell_modifier;
                        cell_direction = cell_type;
                    }

                    switch ( cell_direction )
                    {
                        case Cell.MOVE_EAST:
                            push_direction = CellDirection.MOVING_WEST;
                        case Cell.MOVE_NORTH:
                            push_direction = CellDirection.MOVING_NORTH;
                        case Cell.MOVE_SOUTH:
                            push_direction = CellDirection.MOVING_SOUTH;
                        case Cell.MOVE_WEST:
                            push_direction = CellDirection.MOVING_WEST;
                    }

                    this.map_pushwalls[ y ][ x ] = new Pushwall({
                        direction: push_direction,
                        map: this.map,
                        parent: this.map_pushwalls,
                        texture: cell_texture,
                        type: PushwallType.MOVE,
                        x_cell: x,
                        y_cell: y
                    });

                    this.active_movewalls.push( this.map_pushwalls[ y ][ x ] );
                }
                else if ( cell_type == Cell.SECRET_CELL )
                {
                    cell_value = Cell.SECRET_CELL;
                    cell_texture = cell_modifier;

                    this.map_pushwalls[ y ][ x ] = new Pushwall({
                        map: this.map,
                        parent: this.map_pushwalls,
                        texture: cell_texture,
                        type: PushwallType.PUSH,
                        x_cell: x,
                        y_cell: y
                    });
                }
                else if ( [ Cell.BOUND_CELL, Cell.END_CELL, Cell.WALL_CELL ].indexOf( cell_type ) != -1 )
                {
                    cell_value = cell_type;
                    cell_texture = cell_modifier;
                }
                else
                {
                    cell_value = Cell.EMPTY_CELL;
                    cell_texture = null;
                }

                this.map[ y ][ x ] = new Cell({
                    parent: this.map,
                    texture: cell_texture,
                    value: cell_value,
                    x_cell: x,
                    y_cell: y
                });
            }
        }

        this.player_angle = this.player_starting_angle;
        this.player_x = this.player_starting_x;
        this.player_y = this.player_starting_y;
    }

    function setup_overlays()
    {
        this.overlay_die = new Sprite({
            color: new Color( 1, 1, 1, 0 ),
            depth: 99,
            pos: Luxe.screen.mid,
            texture: Luxe.resources.texture( 'assets/died.jpg' ),
            size: new LuxeVector( this.screen_width, this.screen_height )
        });

        this.overlay_end = new Sprite({
            color: new Color( 1, 1, 1, 0 ),
            depth: 99,
            pos: Luxe.screen.mid,
            texture: Luxe.resources.texture( 'assets/end.jpg' ),
            size: new LuxeVector( this.screen_width, this.screen_height )
        });

        this.overlay_title = new Sprite({
            color: new Color( 1, 1, 1, 0 ),
            depth: 99,
            pos: Luxe.screen.mid,
            texture: Luxe.resources.texture( 'assets/title.jpg' ),
            size: new LuxeVector( this.screen_width, this.screen_height )
        });
    }

    function setup_tables()
    {
        var rad_angle = 0.0;

        // Configure our screen-adjusted table of angles.
        //
        for ( i in 0...360 + 1 )
        {
            this.angles[ i ] = Std.int( i * this.fixed_step );
        }

        // Configure our trigonometric lookup tables, because math is good.
        //
        for ( angle in this.angles[ 0 ]...this.angles[ 360 ] )
        {
            rad_angle = ( 3.272e-4 ) + angle * 2 * 3.141592654 / this.angles[ 360 ];

            this.cos_table[ angle ] = Math.cos( rad_angle );
            this.sin_table[ angle ] = Math.sin( rad_angle );
            this.tan_table[ angle ] = Math.tan( rad_angle );

            this.inv_cos_table[ angle ] = 1.0 / Math.cos( rad_angle );
            this.inv_sin_table[ angle ] = 1.0 / Math.sin( rad_angle );
            this.inv_tan_table[ angle ] = 1.0 / Math.tan( rad_angle );

            if ( angle >= this.angles[ 0 ] && angle < this.angles[ 180 ] )
                this.y_step[ angle ] = Math.abs( this.tan_table[ angle ] * Cell.HEIGHT );
            else
                this.y_step[ angle ] = -Math.abs( this.tan_table[ angle ] * Cell.HEIGHT );

            if ( angle >= this.angles[ 90 ] && angle < this.angles[ 270 ] )
                this.x_step[ angle ] = -Math.abs( this.inv_tan_table[ angle ] * Cell.WIDTH );
            else
                this.x_step[ angle ] = Math.abs( this.inv_tan_table[ angle ] * Cell.WIDTH );
        }

        // Note: No fish were harmed in the creation of this lookup table.  :-)
        //
        for ( angle in -this.angles[ this.half_fov ]...this.angles[ this.half_fov ] )
        {
            rad_angle = ( 3.272e-4 ) + angle * 2 * 3.141592654 / this.angles[ 360 ];
            this.fish_eye_table[ angle + this.angles[ this.half_fov ] ] = 1.0 / Math.cos( rad_angle );
        }

        // Configure some basic colors for our various map cells.
        //
        this.wall_colors = [
            '0' => 0x000000,
            '1' => 0xAF8152,
            '2' => 0x995720,
            '3' => 0x815029,
            '4' => 0xA09885,
            '5' => 0xAF8152,
            '6' => 0x995720,
            '7' => 0x815029,
            '8' => 0xA09885,
            '9' => 0xDFDFDF,
            'D' => 0x55B315,
            'E' => 0xFFFFFF
        ];
    }                    

    function setup_variables()
    {
        this.player_angle = 0;
        this.player_fov = 60;
        this.player_move_x = 0;
        this.player_move_y = 0;
        this.player_starting_angle = 90;
        this.player_starting_x = 0;
        this.player_starting_y = 0;
        this.player_x = 0;
        this.player_y = 0;

        this.half_fov = Std.int( this.player_fov / 2 );
        this.screen_width = Luxe.screen.width;
        this.screen_height = Luxe.screen.height;

        this.view_width = 320;
        this.view_height = 240;
        this.view_pixels = this.view_width * this.view_height;

        this.scale_factor = 16384;

        this.fixed_shift = 16;
        this.fixed_factor = 1 << this.fixed_shift;
        this.fixed_angles = Std.int( ( 360 * this.view_width ) / this.player_fov );
        this.fixed_step = this.fixed_angles / 360.0;

        this.ceiling_color = 0x303030;
        this.floor_color = 0x151515;

        this.draw_ceiling = true;
        this.draw_floor = false;
        this.draw_walls = true;
        this.draw_textures = true;
    }
                
    function ray_cast( x_start, y_start, angle )
    {
        var cast_angle = ( angle - this.angles[ this.half_fov ] + this.angles[ 360 ] ) % this.angles[ 360 ];

        for ( ray in 1...this.view_width )
        {
            this.x_dist = cast_x_ray( x_start, y_start, cast_angle );
            this.y_dist = cast_y_ray( x_start, y_start, cast_angle );

            if ( this.x_dist < this.y_dist )
                this.cast_results[ ray ] =
                {
                    dark_wall: true,
                    dist: this.x_dist,
                    intercept: this.y_intercept,
                    map_x: this.x_x_cell,
                    map_y: this.x_y_cell,
                    map_type: this.x_map_cell.value,
                    offset: this.x_offset,
                    scale: Math.round( this.fish_eye_table[ ray ] * ( this.scale_factor / ( 1e-10 + this.x_dist ) ) ),
                    texture: this.x_map_cell.texture
                };
            else
                this.cast_results[ ray ] =
                {
                    dark_wall: false,
                    dist: this.y_dist,
                    intercept: this.x_intercept,
                    map_x: this.y_x_cell,
                    map_y: this.y_y_cell,
                    map_type: this.y_map_cell.value,
                    offset: this.y_offset,
                    scale: Math.round( this.fish_eye_table[ ray ] * ( this.scale_factor / ( 1e-10 + this.y_dist ) ) ),
                    texture: this.y_map_cell.texture
                };

            cast_angle = ( cast_angle + 1 ) % this.angles[ 360 ];
        }
    }

    function show_checkout()
    {
        this.overlay_die.color.tween( 1.0, { a: 0.75 });
    }

    function show_parole()
    {
        this.overlay_end.color.tween( 1.0, { a: 0.75 });
    }

    function show_title()
    {
        this.overlay_title.color.tween( 1.0, { a: 1.0 });
    }

    override function update( dt:Float )
    {
        if ( this.game_state == GameState.PLAYING )
        {
            apply_input( dt );
            check_collisions();
            update_movewalls( dt );
            update_pushwalls( dt );
            update_buffer();
        }
    }

    function update_buffer()
    {
        ray_cast( this.player_x, this.player_y, this.player_angle );
        clear_buffer();
        populate_buffer();
        draw_buffer();
    }

    function update_movewalls( delta_time:Float )
    {
        if ( this.active_movewalls.length == 0 ) return;

        for ( movewall in this.active_movewalls )
        {
            movewall.update( delta_time );

            if ( movewall.state == PushwallState.FINISHED )
                this.active_movewalls.remove( movewall );
        }
    }

    function update_pushwalls( delta_time:Float )
    {
        if ( this.active_pushwalls.length == 0 ) return;

        for ( pushwall in this.active_pushwalls )
        {
            pushwall.update( delta_time );

            if ( pushwall.state == PushwallState.FINISHED )
                this.active_pushwalls.remove( pushwall );
        }
    }
}
