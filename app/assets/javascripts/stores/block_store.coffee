McFly           = require 'mcfly'
Flux            = new McFly()


# Data
_blocks = {}
_persisted = {}
_trainingModule = {}
_editableBlockIds = []

# Utilities
setBlocks = (data, persisted=false) ->
  for week in data
    for block, i in week.blocks
      _blocks[block.id] = block
      _persisted[block.id] = $.extend(true, {}, block) if persisted
  BlockStore.emitChange()

updatePersisted = ->
  for block_id  in Object.keys(_blocks)
    _persisted[block_id] = $.extend(true, {}, _blocks[block_id])

setBlock = (data, quiet) ->
  _blocks[data.id] = data
  BlockStore.emitChange() unless quiet

setTrainingModule = (module) ->
  _trainingModule = module
  BlockStore.emitChange()

addBlock = (week_id) ->
  week_blocks = BlockStore.getBlocksInWeek week_id
  week_blocks = $.grep week_blocks, (block) -> !block.deleted
  setBlock {
    id: Date.now(),
    is_new: true,
    kind: 0,
    title: "",
    content: "",
    gradeable_id: null,
    week_id: week_id,
    order: week_blocks.length,
    duration: null
  }

removeBlock = (block_id) ->
  delete _blocks[block_id]
  BlockStore.emitChange()

insertBlock = (block, toWeek, afterBlock) ->
  WeekStore = require('./week_store')
  fromWeekId = block.week_id
  block.week_id = toWeek.id

  if afterBlock
    block.order = afterBlock.order + .5
  else
    block.order = -1

  fromWeekBlocks = BlockStore.getBlocksInWeek(block.week_id)
  fromWeekBlocks.forEach (b, i) ->
    b.order = i
    setBlock b, true

  if fromWeekId != toWeek.id
    toWeekBlocks = BlockStore.getBlocksInWeek(toWeek.id)
    toWeekBlocks.forEach (b, i) ->
      b.order = i
      setBlock b, true

  #TODO: Trigger update on weekstore?
  BlockStore.emitChange()

setEditableBlockId = (blockId) ->
  _editableBlockIds.push(blockId)
  BlockStore.emitChange()


# Store
BlockStore = Flux.createStore
  getBlock: (block_id) ->
    return _blocks[block_id]
  getBlocks: ->
    block_list = []
    for block_id in Object.keys(_blocks)
      block_list.push _blocks[block_id]
    return block_list
  getBlocksInWeek: (week_id) ->
    _.filter(_blocks, (block) -> block.week_id == week_id)
      .sort((a,b) -> a.order - b.order)
  restore: ->
    _blocks = $.extend(true, {}, _persisted)
    BlockStore.emitChange()
  getTrainingModule: ->
    return _trainingModule
  getEditableBlockId: ->
    return _editableBlockIds
  clearEditableBlockIds: ->
    _editableBlockIds = []
    BlockStore.emitChange()
  cancelBlockEditable: (block_id) ->
    _editableBlockIds.splice(_editableBlockIds.indexOf(block_id), 1)
    BlockStore.emitChange()

, (payload) ->
  data = payload.data
  switch(payload.actionType)
    when 'RECEIVE_TIMELINE', 'SAVED_TIMELINE', 'WIZARD_SUBMITTED'
      _blocks = {}
      setBlocks data.course.weeks, true
      break
    when 'ADD_BLOCK'
      addBlock data.week_id
      break
    when 'UPDATE_BLOCK'
      setBlock data.block, data.quiet
      break
    when 'DELETE_BLOCK'
      removeBlock data.block_id
      break
    when 'INSERT_BLOCK'
      insertBlock data.block, data.toWeek, data.afterBlock
      break
    when 'SET_BLOCK_EDITABLE'
      setEditableBlockId data.block_id
  return true

module.exports = BlockStore
