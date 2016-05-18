import haxe.ds.Vector;

typedef CellOptions =
{
    @:optional var bottom  : Float;
    @:optional var left    : Float;
    @:optional var offset  : Float;
    @:required var parent  : Vector<Vector<Cell>>;
    @:optional var right   : Float;
    @:required var texture : String;
    @:optional var top     : Float;
    @:required var value   : String;
    @:required var x_cell  : Int;
    @:required var y_cell  : Int;
}

class Cell
{
    public static var HEIGHT = 64;
    public static var WIDTH  = 64;
    public static var HALF   = 32;
    public static var MARGIN = 24;

    public static var BOUND_CELL    = "B";
    public static var DOOR_CELL     = "D";
    public static var DOOR_TYPES    = "- |".split( " " );
    public static var END_CELL      = "E";
    public static var EMPTY_CELL    = ".";
    public static var MOVE_CELL     = "M";
    public static var MOVE_EAST     = "<";
    public static var MOVE_NORTH    = "^";
    public static var MOVE_SOUTH    = "v";
    public static var MOVE_WEST     = ">";
    public static var MOVE_TEXTURES = "1 2 3 4".split( " " );
    public static var PLAYER_CELL   = "S";
    public static var PLAYER_DOWN   = "v";
    public static var PLAYER_LEFT   = "<";
    public static var PLAYER_RIGHT  = ">";
    public static var PLAYER_UP     = "^";
    public static var SECRET_CELL   = "P";
    public static var WALL_CELL     = "W";

    public var bottom( default, default )  : Float;
    public var left( default, default )    : Float;
    public var parent( default, default )  : Vector<Vector<Cell>>;
    public var offset( default, default )  : Float;
    public var right( default, default )   : Float;
    public var texture( default, default ) : String;
    public var top( default, default )     : Float;
    public var value( default, default )   : String;
    public var x_cell( default, default )  : Int;
    public var y_cell( default, default )  : Int;

    public function new( options:CellOptions )
    {
        this.bottom  = options.bottom;
        this.left    = options.left;
        this.parent  = options.parent;
        this.offset  = options.offset;
        this.right   = options.right;
        this.texture = options.texture;
        this.top     = options.top;
        this.value   = options.value;
        this.x_cell  = options.x_cell;
        this.y_cell  = options.y_cell;

        if ( options.bottom == null ) this.bottom = 0;
        if ( options.left == null ) this.left = 0;
        if ( options.offset == null ) this.offset = 0;
        if ( options.right == null ) this.right = 0;
        if ( options.top == null ) this.top = 0;
        if ( options.value == null ) this.value = EMPTY_CELL;
    }
}
