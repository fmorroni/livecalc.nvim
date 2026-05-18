---@alias AstNodeType
---| "number"
---| "identifier"
---| "parenthesized_expression"
---| "unary_expression"
---| "binary_expression"
---| "assignment"
---| "error"

---@class NumberNode
---@field type "number"
---@field value number

---@class IdentifierNode
---@field type "identifier"
---@field name string

---@class UnaryNode
---@field type "unary"
---@field op string
---@field expr AstNode

---@class BinaryNode
---@field type "binary"
---@field op string
---@field left AstNode
---@field right AstNode

---@class AssignmentNode
---@field type "assignment"
---@field name string
---@field value AstNode

---@class ErrorNode
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

