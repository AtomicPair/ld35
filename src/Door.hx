import Cell;
import haxe.ds.Vector;

enum DoorState
{
    CLOSED;
    CLOSING;
    OPEN;
    OPENING;
}

typedef DoorOptions =
{
    @:required var map        : Vector<Vector<Cell>>;
    @:optional var offset     : Float;
    @:optional var open_since : Float;
    @:required var parent     : Vector<Vector<Door>>;
    @:optional var state      : DoorState;
    @:required var x_cell     : Int;
    @:required var y_cell     : Int;
}

class Door
{
    public var map( default, default )        : Vector<Vector<Cell>>;
    public var offset( default, default )     : Float;
    public var open_since( default, default ) : Float;
    public var parent( default, default )     : Vector<Vector<Door>>;
    public var state( default, default )      : DoorState;
    public var x_cell( default, default )     : Int;
    public var y_cell( default, default )     : Int;

    public function new( options:DoorOptions )
    {
        this.map        = options.map;
        this.offset     = options.offset;
        this.open_since = options.open_since;
        this.parent     = options.parent;
        this.state      = options.state;
        this.x_cell     = options.x_cell;
        this.y_cell     = options.y_cell;

        if ( options.state == null ) this.state = DoorState.CLOSED;
        if ( options.x_cell == 0 ) this.x_cell = 0;
        if ( options.y_cell == 0 ) this.y_cell = 0;
    }

    public function update( delta_time )
    {
        switch ( this.state )
        {
            case DoorState.CLOSED:
                return;
            case DoorState.OPENING:
                if ( this.offset >= Cell.WIDTH )
                {
                    this.state = DoorState.OPEN;
                    this.open_since = Date.now().getTime();
                }
                else
                    this.offset += ( 64 * delta_time );
            case DoorState.OPEN:
                if ( Date.now().getTime() - this.open_since > 5000 )
                {
                    this.state = DoorState.CLOSING;
                    this.open_since = 0.0;
                }
            case DoorState.CLOSING:
                if ( this.offset <= 0 )
                    this.state = DoorState.CLOSED;
                else
                    this.offset -= ( 64 * delta_time );
        }
    }
}
