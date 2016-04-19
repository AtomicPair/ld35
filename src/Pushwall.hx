import haxe.ds.Vector;

enum CellDirection
{
    MOVING_EAST;
    MOVING_NORTH;
    MOVING_SOUTH;
    MOVING_WEST;
}

enum PushwallState
{
  STOPPED;
  MOVING;
  FINISHED;
}

enum PushwallType
{
  PUSH;
  MOVE;
}

typedef PushwallOptions =
{
    @:optional var bottom    : Float;
    @:optional var direction : CellDirection;
    @:optional var left      : Float;
    @:required var map       : Vector<Vector<Cell>>;
    @:optional var offset    : Float;
    @:required var parent    : Vector<Vector<Pushwall>>;
    @:optional var right     : Float;
    @:optional var state     : PushwallState;
    @:optional var texture   : String;
    @:optional var to_x_cell : Int;
    @:optional var to_y_cell : Int;
    @:optional var top       : Float;
    @:optional var type      : PushwallType;
    @:required var x_cell    : Int;
    @:required var y_cell    : Int;
}

class Pushwall
{
    public var bottom( default, default )      : Float;
    public var cells_moved( default, default ) : Int;
    public var direction( default, default )   : CellDirection;
    public var left( default, default )        : Float;
    public var map( default, default )         : Vector<Vector<Cell>>;
    public var offset( default, default )      : Float;
    public var parent( default, default )      : Vector<Vector<Pushwall>>;
    public var right( default, default )       : Float;
    public var state( default, default )       : PushwallState;
    public var to_x_cell( default, default )   : Int;
    public var to_y_cell( default, default )   : Int;
    public var texture( default, default )     : String;
    public var top( default, default )         : Float;
    public var type( default, default)         : PushwallType;
    public var x_cell( default, default )      : Int;
    public var y_cell( default, default )      : Int;

    var cell_size       : Int;
    var empty_next_cell : Bool;
    var empty_this_cell : Bool;
    var next_cell       : Cell;
    var next_bottom     : Int;
    var next_left       : Int;
    var next_offset     : Int;
    var next_right      : Int;
    var next_top        : Int;
    var next_x_cell     : Int;
    var next_y_cell     : Int;
    var offset_good     : Bool;
    var push_amount     : Float;
    var push_bottom     : Float;
    var push_left       : Float;
    var push_right      : Float;
    var push_top        : Float;
    var to_offset       : Int;

    var bounding_type = Cell.BOUND_CELL;
    var stop_cell     = 1;

    public function new( options:PushwallOptions )
    {
        this.bottom    = options.bottom;
        this.direction = options.direction;
        this.left      = options.left;
        this.map       = options.map;
        this.offset    = options.offset;
        this.parent    = options.parent;
        this.right     = options.right;
        this.state     = options.state;
        this.texture   = options.texture;
        this.to_x_cell = options.x_cell;
        this.to_y_cell = options.y_cell;
        this.top       = options.top;
        this.type      = options.type;
        this.x_cell    = options.x_cell;
        this.y_cell    = options.y_cell;

        if ( options.state == null ) this.state = PushwallState.STOPPED;
        if ( options.type == null ) this.type = PushwallType.PUSH;

        this.cells_moved  = 0;
        this.bottom       = ( this.y_cell + 1 ) * Cell.HEIGHT;
        this.left         = this.x_cell * Cell.WIDTH;
        this.right        = ( this.x_cell + 1 ) * Cell.WIDTH;
        this.top          = this.y_cell * Cell.HEIGHT;
        this.to_x_cell    = this.x_cell;
        this.to_y_cell    = this.y_cell;
    }

    // Activates the pushwall in the desired direction.
    //
    public function activate( direction:CellDirection )
    {
        if ( this.type == PushwallType.PUSH && this.state != PushwallState.STOPPED )
            return false;
        else if ( this.type == PushwallType.MOVE && this.state != PushwallState.STOPPED )
            return false;
        else
            return reset( direction );
    }

    // Updates the pushwall's current state and position, if active.
    //
    public function update( delta_time:Float )
    {
        if ( this.state == PushwallState.FINISHED ) return;

        switch ( this.type )
        {
            case PushwallType.MOVE:
                this.push_amount = 24 * delta_time;
            case PushwallType.PUSH:
                this.push_amount = 16 * delta_time;
        }

        switch ( this.direction )
        {
            case CellDirection.MOVING_EAST:
                this.cell_size   = Cell.WIDTH;
                this.push_amount = -this.push_amount;
                this.push_left   = this.push_amount;
                this.push_right  = this.push_amount;
                this.push_top    = 0;
                this.push_bottom = 0;
                this.next_x_cell = this.to_x_cell - 1;
                this.next_y_cell = this.to_y_cell;
                this.next_left   = ( this.next_x_cell + 1 ) * Cell.WIDTH;
                this.next_right  = ( this.to_x_cell + 1 ) * Cell.WIDTH;
                this.next_top    = this.to_y_cell * Cell.HEIGHT;
                this.next_bottom = this.next_y_cell * Cell.HEIGHT;
                this.next_offset = this.cell_size;
                this.offset_good = ( this.offset >= -this.cell_size );

            case CellDirection.MOVING_WEST:
                this.cell_size   = Cell.WIDTH;
                this.push_left   = this.push_amount;
                this.push_right  = this.push_amount;
                this.push_top    = 0;
                this.push_bottom = 0;
                this.next_x_cell = this.to_x_cell + 1;
                this.next_y_cell = this.to_y_cell;
                this.next_left   = this.to_x_cell * Cell.WIDTH;
                this.next_right  = this.next_x_cell * Cell.WIDTH;
                this.next_top    = this.to_y_cell * Cell.HEIGHT;
                this.next_bottom = this.next_y_cell * Cell.HEIGHT;
                this.next_offset = -this.cell_size;
                this.offset_good = ( this.offset <= this.cell_size );

            case CellDirection.MOVING_NORTH:
                this.cell_size   = Cell.HEIGHT;
                this.push_amount = -this.push_amount;
                this.push_left   = 0;
                this.push_right  = 0;
                this.push_top    = this.push_amount;
                this.push_bottom = this.push_amount;
                this.next_x_cell = this.to_x_cell;
                this.next_y_cell = this.to_y_cell - 1;
                this.next_left   = this.to_x_cell * Cell.WIDTH;
                this.next_right  = this.next_x_cell * Cell.WIDTH;
                this.next_top    = ( this.next_y_cell + 1 ) * Cell.HEIGHT;
                this.next_bottom = ( this.to_y_cell + 1 ) * Cell.HEIGHT;
                this.next_offset = this.cell_size;
                this.offset_good = ( this.offset >= -this.cell_size );

            case MOVING_SOUTH:
                this.cell_size   = Cell.HEIGHT;
                this.push_left   = 0;
                this.push_right  = 0;
                this.push_top    = this.push_amount;
                this.push_bottom = this.push_amount;
                this.next_x_cell = this.to_x_cell;
                this.next_y_cell = this.to_y_cell + 1;
                this.next_left   = this.to_x_cell * Cell.WIDTH;
                this.next_right  = this.next_x_cell * Cell.WIDTH;
                this.next_top    = this.to_y_cell * Cell.HEIGHT;
                this.next_bottom = this.next_y_cell * Cell.HEIGHT;
                this.next_offset = -this.cell_size;
                this.offset_good = ( this.offset <= this.cell_size );
        }

        this.offset += this.push_amount;
        this.left   += this.push_left;
        this.right  += this.push_right;
        this.top    += this.push_top;
        this.bottom += this.push_bottom;

        if ( this.empty_this_cell )
            this.map[ this.y_cell ][ this.x_cell ].offset += this.push_amount;

        if ( this.empty_next_cell )
            this.map[ this.to_y_cell ][ this.to_x_cell ].offset += this.push_amount;

        if ( !this.offset_good )
        {
            this.cells_moved += 1;
            this.offset = this.push_amount;
            this.parent[ this.y_cell ][ this.x_cell ] = null;
            this.next_cell = this.map[ this.next_y_cell ][ this.next_x_cell ];

            if ( this.empty_this_cell )
            {
                this.map[ this.y_cell ][ this.x_cell ].offset  = 0;
                this.map[ this.y_cell ][ this.x_cell ].texture = null;
                this.map[ this.y_cell ][ this.x_cell ].value   = Cell.EMPTY_CELL;
            }

            if ( this.empty_next_cell )
            {
                this.map[ this.to_y_cell ][ this.to_x_cell ].offset  = this.push_amount;
                this.map[ this.to_y_cell ][ this.to_x_cell ].texture = this.texture;
                this.map[ this.to_y_cell ][ this.to_x_cell ].value   = Cell.SECRET_CELL;
            }

            if ( this.next_cell != null && this.next_cell.value != this.bounding_type )
            {
                this.x_cell          = this.to_x_cell;
                this.y_cell          = this.to_y_cell;
                this.to_x_cell       = this.next_x_cell;
                this.to_y_cell       = this.next_y_cell;
                this.empty_this_cell = this.empty_next_cell;

                this.left      = this.next_left + this.push_amount;
                this.right     = this.next_right + this.push_amount;
                this.top       = this.next_top + this.push_amount;
                this.bottom    = this.next_bottom + this.push_amount;

                this.parent[ this.y_cell ][ this.x_cell ]       = this;
                this.parent[ this.to_y_cell ][ this.to_x_cell ] = this;

                if ( this.map[ this.to_y_cell ][ this.to_x_cell ].value == Cell.EMPTY_CELL )
                {
                    this.empty_next_cell = true;
                    this.map[ this.to_y_cell ][ this.to_x_cell ].offset  = this.next_offset + this.push_amount;
                    this.map[ this.to_y_cell ][ this.to_x_cell ].texture = this.texture;
                    this.map[ this.to_y_cell ][ this.to_x_cell ].value   = Cell.SECRET_CELL;
                }
                else
                    this.empty_next_cell = false;
            }
            else
            {
                this.offset = 0;
                this.bottom = ( this.y_cell + 1 ) * Cell.HEIGHT;
                this.left   = this.x_cell * Cell.WIDTH;
                this.right  = ( this.x_cell + 1 ) * Cell.WIDTH;
                this.top    = this.y_cell * Cell.HEIGHT;
                this.x_cell = this.to_x_cell;
                this.y_cell = this.to_y_cell;

                switch ( this.type )
                {
                    case PushwallType.PUSH:
                        this.direction = null;
                        this.state     = PushwallState.FINISHED;
                    case PushwallType.MOVE:
                        switch ( this.direction )
                        {
                            case CellDirection.MOVING_WEST:
                                reset( CellDirection.MOVING_EAST );
                            case CellDirection.MOVING_EAST:
                                reset( CellDirection.MOVING_WEST );
                            case CellDirection.MOVING_NORTH:
                                reset( CellDirection.MOVING_SOUTH );
                            case CellDirection.MOVING_SOUTH:
                                reset( CellDirection.MOVING_NORTH );
                        }
                }
            }
        }
    }

    private function reset( direction:CellDirection )
    {
        switch ( direction )
        {
            case CellDirection.MOVING_EAST:
                if ( this.map[ this.y_cell ][ this.x_cell - this.stop_cell ].value == this.bounding_type ) return false;

                this.direction = CellDirection.MOVING_EAST;
                this.offset    = 0;
                this.state     = PushwallState.MOVING;
                this.to_offset = Cell.WIDTH;
                this.to_x_cell = this.x_cell - 1;
                this.to_y_cell = this.y_cell;

            case CellDirection.MOVING_WEST:
                if ( this.map[ this.y_cell ][ this.x_cell + this.stop_cell ].value == this.bounding_type ) return false;

                this.direction = CellDirection.MOVING_WEST;
                this.offset    = 0;
                this.state     = PushwallState.MOVING;
                this.to_offset = -Cell.WIDTH;
                this.to_x_cell = this.x_cell + 1;
                this.to_y_cell = this.y_cell;

            case CellDirection.MOVING_NORTH:
                if ( this.map[ this.y_cell - this.stop_cell ][ this.x_cell ].value == this.bounding_type ) return false;

                this.direction = CellDirection.MOVING_NORTH;
                this.offset    = 0;
                this.state     = PushwallState.MOVING;
                this.to_offset = Cell.HEIGHT;
                this.to_x_cell = this.x_cell;
                this.to_y_cell = this.y_cell - 1;

            case CellDirection.MOVING_SOUTH:
                if ( this.map[ this.y_cell + this.stop_cell ][ this.x_cell ].value == this.bounding_type ) return false;

                this.direction = CellDirection.MOVING_SOUTH;
                this.offset    = 0;
                this.state     = PushwallState.MOVING;
                this.to_offset = -Cell.HEIGHT;
                this.to_x_cell = this.x_cell;
                this.to_y_cell = this.y_cell + 1;
        }

        this.bottom = ( this.y_cell + 1 ) * Cell.HEIGHT;
        this.left   = this.x_cell * Cell.WIDTH;
        this.right  = ( this.x_cell + 1 ) * Cell.WIDTH;
        this.top    = this.y_cell * Cell.HEIGHT;

        this.parent[ this.y_cell ][ this.x_cell ]       = this;
        this.parent[ this.to_y_cell ][ this.to_x_cell ] = this;

        if ( [ Cell.EMPTY_CELL, Cell.SECRET_CELL ].indexOf( this.map[ this.y_cell ][ this.x_cell ].value ) != -1 )
        {
            this.empty_this_cell = true;
            this.map[ this.y_cell ][ this.x_cell ].offset  = this.offset;
            this.map[ this.y_cell ][ this.x_cell ].texture = this.texture;
            this.map[ this.y_cell ][ this.x_cell ].value   = Cell.SECRET_CELL;
        }
        else
            this.empty_this_cell = false;

        if ( this.map[ this.to_y_cell ][ this.to_x_cell ].value == Cell.EMPTY_CELL )
        {
            this.empty_next_cell = true;
            this.map[ this.to_y_cell ][ this.to_x_cell ].offset  = this.to_offset;
            this.map[ this.to_y_cell ][ this.to_x_cell ].texture = this.texture;
            this.map[ this.to_y_cell ][ this.to_x_cell ].value   = Cell.SECRET_CELL;
        }
        else
            this.empty_next_cell = false;

        return true;
    }
}
