---@class RuntimeNumber
---@field type "number"
---@field value number
---@field units Units

---@class RuntimeFunction
---@field type "function"
---@field params FunctionParameterNode[]
---@field return_units Units?
---@field body AstNode
---@field closure Env

---@alias RuntimeValue
---| RuntimeNumber
---| RuntimeFunction

---@class ResultSuccess
---@field type "success"
---@field value RuntimeValue

---@class EvalError
---@field msg string
---@field range NodeRange

---@class ResultError
---@field type "error"
---@field errors EvalError[]

---@alias Result
---| ResultSuccess
---| ResultError

---@alias Env table<string, RuntimeValue>

---@class LineResult
---@field line integer
---@field result Result

---@class EvalState
---@field env Env
---@field line_results LineResult[]
