---@class NodeRange
---@field start_row integer
---@field end_row integer
---@field start_col integer
---@field end_col integer

---@class BaseNode
---@field type string
---@field range NodeRange

---@class NumberNode : BaseNode
---@field type "number"
---@field value number

---@class BooleanNode : BaseNode
---@field type "boolean"
---@field value boolean

---@class IdentifierNode : BaseNode
---@field type "identifier"
---@field name string

---@alias UnaryNodeType "unary_numeric" | "unary_boolean"

---@class UnaryNode : BaseNode
---@field type UnaryNodeType
---@field op string
---@field expr AstNode

---@alias BinaryNodeType "binary_numeric" | "binary_boolean"

---@class BinaryNode : BaseNode
---@field type BinaryNodeType
---@field op string
---@field left AstNode
---@field right AstNode

---@class AssignmentNode : BaseNode
---@field type "assignment"
---@field identifier string
---@field value AstNode

---@alias Units table<string, number>

---@class UnitAttachNode : BaseNode
---@field type "unit_attach"
---@field expr AstNode
---@field units Units

---@class IdentifierCallNode : BaseNode
---@field type "identifier_call"
---@field identifier IdentifierNode
---@field args AstNode[]

---@class BuiltinCallNode : BaseNode
---@field type "builtin_call"
---@field identifier IdentifierNode
---@field args AstNode[]

---@class InlineFunctionCallNode : BaseNode
---@field type "inline_function_call"
---@field fn FunctionNode
---@field args AstNode[]

---@class FunctionParameterNode : BaseNode
---@field type "function_parameter"
---@field name string
---@field unit Units?

---@class FunctionNode : BaseNode
---@field type "function_def"
---@field body AstNode
---@field params FunctionParameterNode[]

---@class BuiltinConstant : BaseNode
---@field type "builtin_constant"
---@field identifier IdentifierNode

---@class ErrorNode : BaseNode
---@field type "error"
---@field msg string

---@alias AstNode
---| NumberNode
---| BooleanNode
---| IdentifierNode
---| UnaryNode
---| BinaryNode
---| AssignmentNode
---| UnitAttachNode
---| IdentifierCallNode
---| BuiltinCallNode
---| InlineFunctionCallNode
---| BuiltinConstant
---| FunctionNode
---| ErrorNode
