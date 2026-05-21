-- lua/livecalc/ast/types.lua

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

---@class IdentifierNode : BaseNode
---@field type "identifier"
---@field name string

---@class UnaryNode : BaseNode
---@field type "unary"
---@field op string
---@field expr AstNode

---@class BinaryNode : BaseNode
---@field type "binary"
---@field op string
---@field left AstNode
---@field right AstNode

---@class AssignmentNode : BaseNode
---@field type "assignment"
---@field identifier string
---@field value AstNode

---@class ErrorNode : BaseNode
---@field type "error"
---@field msg string

---@alias AstNode
---| NumberNode
---| IdentifierNode
---| UnaryNode
---| BinaryNode
---| AssignmentNode
---| ErrorNode

---@alias AstConversionFun fun(bufnr: integer, node: TSNode): AstNode
