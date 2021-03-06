local assets = require("assets")
local netman = require("net.netman")
local base = require("entities.base")
local tire = require("entities.tire")
local util = require("util.util")
local ctx = require("gamectx.global")

local player = {}

function player:create(x, y, id)
  local p = {
    img=assets.img.car,
    width=assets.img.car:getWidth(),
    height=assets.img.car:getHeight(),

    body=love.physics.newBody(world, x, y, "dynamic"),
    shape=love.physics.newRectangleShape(assets.img.car:getWidth(),
                                         assets.img.car:getHeight()),
    fixture=nil,

    tires={},
    fljoint=nil,
    frjoint=nil,

    desiredSpeed=0,
    desiredTorque=0,
    desiredAngle=0,

    lastX=x,
    lastY=y,
  }
  setmetatable(p, {__index=base})

  if id then
    p:setId(id)
  else
    p:genId()
  end

  -- attach fixture to body and set density to 1.0
  p.fixture = love.physics.newFixture(p.body, p.shape, 1.0)

  local rearTireMaxDriveForce = 300
  local frontTireMaxDriveForce = 500
  local rearTireMaxLateralImpulse = 8.5
  local frontTireMaxLateralImpulse = 7.5

  local wheeltrack = p.width/2
  local wheelbase = p.height/2 - 4

  -- create tires
  local fltire = tire:create(x - wheeltrack, y + wheelbase, frontTireMaxDriveForce, frontTireMaxLateralImpulse)
  p.fljoint = love.physics.newRevoluteJoint(fltire.body, p.body, x - wheeltrack, y + wheelbase)
  p.fljoint:setLimits(0, 0)
  p.fljoint:setLimitsEnabled(true)
  table.insert(p.tires, fltire)

  local frtire = tire:create(x + wheeltrack, y + wheelbase, frontTireMaxDriveForce, frontTireMaxLateralImpulse)
  p.frjoint = love.physics.newRevoluteJoint(frtire.body, p.body, x + wheeltrack, y + wheelbase)
  p.frjoint:setLimits(0, 0)
  p.frjoint:setLimitsEnabled(true)
  table.insert(p.tires, frtire)

  local rltire = tire:create(x - wheeltrack, y - wheelbase, rearTireMaxDriveForce, rearTireMaxLateralImpulse)
  p.rljoint = love.physics.newRevoluteJoint(rltire.body, p.body, x - wheeltrack, y - wheelbase)
  p.rljoint:setLimits(0, 0)
  p.rljoint:setLimitsEnabled(true)
  table.insert(p.tires, rltire)

  local rrtire = tire:create(x + wheeltrack, y - wheelbase, rearTireMaxDriveForce, rearTireMaxLateralImpulse)
  p.rrjoint = love.physics.newRevoluteJoint(rrtire.body, p.body, x + wheeltrack, y - wheelbase)
  p.rrjoint:setLimits(0, 0)
  p.rrjoint:setLimitsEnabled(true)
  table.insert(p.tires, rrtire)

  function p:destroy()
    -- destroy tires
    for _, t in pairs(self.tires) do
      t:destroy()
    end

    p.body:destroy()
  end

  local maxTurnPerTimeStep = 320*math.pi/60

  function p:update(dt)
    -- turn wheels
    local angleNow = self.fljoint:getJointAngle()
    local angleToTurn = self.desiredAngle - angleNow
    angleToTurn = util:clamp(angleToTurn, -maxTurnPerTimeStep, maxTurnPerTimeStep)
    local newAngle = angleNow + angleToTurn
    self.fljoint:setLimits(newAngle, newAngle)
    self.frjoint:setLimits(newAngle, newAngle)

    for _, t in pairs(self.tires) do
      t:update(self.desiredSpeed, self.desiredTorque)
    end

    netman:sendCoord(self)
  end

  function p:draw()
    -- draw chassis
    love.graphics.draw(self.img,
    self.body:getX(),
    self.body:getY(),
    self.body:getAngle() - math.pi,
    1,
    1,
    self.width/2,
    self.height/2)

    -- bounding box
    if ctx:get('debugEnabled') then
      love.graphics.polygon("line", self.body:getWorldPoints(self.shape:getPoints()))
    end

    -- draw tires
    for _, t in pairs(self.tires) do
      t:draw()
    end
  end

  function p:getPosition()
    return self.body:getX(), self.body:getY()
  end

  function p:getTrajectory()
    local vx, vy = self.body:getLinearVelocity()
    return math.atan2(vy, vx)
  end

  function p:getSprite()
    return self.img
  end

  function p:setSprite(img)
    self.img = img
  end

  function p:setSpriteFromData(sprite)
    local data = love.image.newImageData(32, 32, sprite.format, sprite.data)
    self.img = love.graphics.newImage(data)
  end

  local maxForwardSpeed = 250
  local maxReverseSpeed = -40

  function p:beginAccelerating()
    self.desiredSpeed = maxForwardSpeed
  end

  function p:beginBraking()
  end

  function p:beginReversing()
    self.desiredSpeed = maxReverseSpeed
  end

  local lockAngle = 40*math.pi/180

  function p:beginTurningLeft()
    self.desiredTorque = 15
    self.desiredAngle = lockAngle
  end

  function p:beginTurningRight()
    self.desiredTorque = -15
    self.desiredAngle = -lockAngle
  end

  function p:endAccelerating()
    self.desiredSpeed = 0
  end

  function p:endBraking()
  end

  function p:endReversing()
    self.desiredSpeed = 0
  end

  function p:endTurningLeft()
    self.desiredTorque = 0
    self.desiredAngle = 0
  end

  function p:endTurningRight()
    self.desiredTorque = 0
    self.desiredAngle = 0
  end

  return p
end

return player
