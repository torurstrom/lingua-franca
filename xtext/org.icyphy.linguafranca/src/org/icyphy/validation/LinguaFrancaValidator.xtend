/* Validation checks for Lingua Franca code. */

/*************
 * Copyright (c) 2019, The University of California at Berkeley.

 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:

 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.

 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.

 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON 
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 ***************/
package org.icyphy.validation

import java.util.ArrayList
import java.util.Arrays
import java.util.HashSet
import java.util.List
import org.eclipse.core.resources.IMarker
import org.eclipse.core.resources.IResource
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.Path
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.xtext.validation.Check
import org.icyphy.ModelInfo
import org.icyphy.Targets
import org.icyphy.Targets.BuildTypes
import org.icyphy.Targets.LoggingLevels
import org.icyphy.Targets.TargetProperties
import org.icyphy.TimeValue
import org.icyphy.linguaFranca.Action
import org.icyphy.linguaFranca.ActionOrigin
import org.icyphy.linguaFranca.Assignment
import org.icyphy.linguaFranca.Connection
import org.icyphy.linguaFranca.Deadline
import org.icyphy.linguaFranca.Host
import org.icyphy.linguaFranca.IPV4Host
import org.icyphy.linguaFranca.IPV6Host
import org.icyphy.linguaFranca.Input
import org.icyphy.linguaFranca.Instantiation
import org.icyphy.linguaFranca.KeyValuePair
import org.icyphy.linguaFranca.LinguaFrancaPackage.Literals
import org.icyphy.linguaFranca.Model
import org.icyphy.linguaFranca.NamedHost
import org.icyphy.linguaFranca.Output
import org.icyphy.linguaFranca.Parameter
import org.icyphy.linguaFranca.Port
import org.icyphy.linguaFranca.Preamble
import org.icyphy.linguaFranca.Reaction
import org.icyphy.linguaFranca.Reactor
import org.icyphy.linguaFranca.StateVar
import org.icyphy.linguaFranca.Target
import org.icyphy.linguaFranca.TimeUnit
import org.icyphy.linguaFranca.Timer
import org.icyphy.linguaFranca.Type
import org.icyphy.linguaFranca.TypedVariable
import org.icyphy.linguaFranca.Value
import org.icyphy.linguaFranca.Variable
import org.icyphy.linguaFranca.Visibility

import static extension org.icyphy.ASTUtils.*
import java.util.LinkedList
import org.icyphy.linguaFranca.VarRef

/**
 * Custom validation checks for Lingua Franca programs.
 *  
 * @author{Edward A. Lee <eal@berkeley.edu>}
 * @author{Marten Lohstroh <marten@berkeley.edu>}
 * @author{Matt Weber <matt.weber@berkeley.edu>}
 * @author(Christian Menard <christian.menard@tu-dresden.de>}
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation
 */
class LinguaFrancaValidator extends AbstractLinguaFrancaValidator {

    var reactorClasses = newHashSet()
    var parameters = newHashSet()
    var inputs = newHashSet()
    var outputs = newHashSet()
    var timers = newHashSet()
    var actions = newHashSet()
    var allNames = newHashSet() // Names of contained objects must be unique.
    var Targets target;

    var info = new ModelInfo()

    /**
     * Regular expression to check the validity of IPV4 addresses (due to David M. Syzdek).
     */
    static val ipv4Regex = "((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}" +
                                "(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"

    /**
     * Regular expression to check the validity of IPV6 addresses (due to David M. Syzdek),
     * with minor adjustment to allow up to six IPV6 segments (without truncation) in front
     * of an embedded IPv4-address. 
     **/
    static val ipv6Regex = 
                "(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|" +
                "([0-9a-fA-F]{1,4}:){1,7}:|" + 
                "([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|" +
                "([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|" + 
                "([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|" + 
                "([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|" + 
                "([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|" + 
                 "[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|" + 
                                 ":((:[0-9a-fA-F]{1,4}){1,7}|:)|" +
        "fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|" + 
        "::(ffff(:0{1,4}){0,1}:){0,1}" + ipv4Regex + "|" + 
        "([0-9a-fA-F]{1,4}:){1,4}:"    + ipv4Regex + "|" +
        "([0-9a-fA-F]{1,4}:){1,6}"     + ipv4Regex + ")"                          

    static val usernameRegex = "^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\\$)$"

    static val hostOrFQNRegex = "^([a-z0-9]+(-[a-z0-9]+)*)|(([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,})$"

    // //////////////////////////////////////////////////
    // // Helper functions for checks to be performed on multiple entities
    // Check the name of a feature for illegal substrings.
    private def checkName(String name, EStructuralFeature feature) {

        // Raises an error if the string starts with two underscores.
        if (name.length() >= 2 && name.substring(0, 2).equals("__")) {
            error(UNDERSCORE_MESSAGE + name, feature)
        }

        if (this.target.keywords.contains(name)) {
            error(RESERVED_MESSAGE + name, feature)
        }

        if (this.target == Targets.TS) {
            // "actions" is a reserved word within a TS reaction
            if (name.equals("actions")) {
                error(ACTIONS_MESSAGE + name, feature)
            }
        }

    }

    // //////////////////////////////////////////////////
    // // Functions to set up data structures for performing checks.
    // FAST ensures that these checks run whenever a file is modified.
    // Alternatives are NORMAL (when saving) and EXPENSIVE (only when right-click, validate).
    @Check(FAST)
    def reset(Model model) {
        reactorClasses.clear()
    }

    @Check(FAST)
    def resetSets(Reactor reactor) {
        parameters.clear()
        inputs.clear()
        outputs.clear()
        timers.clear()
        actions.clear()
        allNames.clear()
    }

    // //////////////////////////////////////////////////
    // // The following checks are in alphabetical order.
    @Check(FAST)
    def checkAction(Action action) {
        checkName(action.name, Literals.VARIABLE__NAME)
        if (action.origin == ActionOrigin.NONE) {
            error(
                "Action must have modifier `logical` or `physical`.",
                Literals.ACTION__ORIGIN
            )
        }

        if (allNames.contains(action.name)) {
            error(
                UNIQUENESS_MESSAGE + action.name,
                Literals.VARIABLE__NAME
            )
        }
        actions.add(action.name);
        allNames.add(action.name)
    }

    @Check(FAST)
    def checkAssignment(Assignment assignment) {
        // If the left-hand side is a time parameter, make sure the assignment has units
        if (assignment.lhs.isOfTimeType) {
            if (assignment.rhs.size > 1) {
                 error("Incompatible type.", Literals.ASSIGNMENT__RHS)
            } else {
                val v = assignment.rhs.get(0)
                if (!v.isValidTime) {
                    if (v.parameter === null) {
                        // This is a value. Check that units are present.
                    error(
                        "Invalid time units: " + assignment.rhs +
                            ". Should be one of " + TimeUnit.VALUES.filter [
                                it != TimeUnit.NONE
                            ], Literals.ASSIGNMENT__RHS)
                    } else {
                        // This is a reference to another parameter. Report problem.
                error(
                    "Cannot assign parameter: " +
                        v.parameter.name + " to " +
                        assignment.lhs.name +
                        ". The latter is a time parameter, but the former is not.",
                    Literals.ASSIGNMENT__RHS)
                    }
                }
            }
            // If this assignment overrides a parameter that is used in a deadline,
            // report possible overflow.
            if (this.target == Targets.C &&
                this.info.overflowingAssignments.contains(assignment)) {
                error(
                    "Time value used to specify a deadline exceeds the maximum of " +
                        TimeValue.MAX_LONG_DEADLINE + " nanoseconds.",
                    Literals.ASSIGNMENT__RHS)
            }
        }
        // FIXME: lhs is list => rhs is list
        // lhs is fixed with size n => rhs is fixed with size n
        // FIXME": similar checks for decl/init
        // Specifically for C: list can only be literal or time lists
    }

    @Check(FAST)
    def checkConnection(Connection connection) {

        // Report if connection is part of a cycle.
        for (cycle : this.info.reactionGraph.cycles) {
            val lp = connection.leftPort
            val rp = connection.rightPort
            var leftInCycle = false
            val reactorName = (connection.eContainer as Reactor).name
            
            if ((lp.container === null && cycle.exists [
                it.node === lp.variable
            ]) || cycle.exists [
                (it.node === lp.variable && it.instantiation === lp.container)
            ]) {
                leftInCycle = true
            }

            if ((rp.container === null && cycle.exists [
                it.node === rp.variable
            ]) || cycle.exists [
                (it.node === rp.variable && it.instantiation === rp.container)
            ]) {
                if (leftInCycle) {
                    // Only report of _both_ referenced ports are in the cycle.
                    error('''Connection in reactor «reactorName» creates ''' + 
                    '''a cyclic dependency between «lp.toText» and ''' +
                    '''«rp.toText».''', Literals.CONNECTION__DELAY
                    )
                }
            }
        }        
        
        // Make sure that if either side of the connection has an arraySpec
        // (has the form port[i]), then the port is defined as a multiport.
        if (connection.rightPort.variableArraySpec !== null &&
                (connection.rightPort.variable as Port).arraySpec === null) {
            error("Port is not a multiport: " + connection.rightPort.toText,
                Literals.CONNECTION__RIGHT_PORT
            )
        }
        if (connection.leftPort.variableArraySpec !== null &&
                (connection.leftPort.variable as Port).arraySpec === null) {
            error("Port is not a multiport: " + connection.leftPort.toText,
                Literals.CONNECTION__RIGHT_PORT
            )
        }
        
        val reactor = connection.eContainer as Reactor
        
        // Make sure the right port is not already an effect of a reaction.
        // FIXME: support multiports.
        for (reaction : reactor.reactions) {
            for (effect : reaction.effects) {
                if (connection.rightPort.container === effect.container &&
                    connection.rightPort.variable === effect.variable) {
                    error(
                        "Cannot connect: Port named '" + effect.variable.name +
                            "' is already effect of a reaction.",
                        Literals.CONNECTION__RIGHT_PORT)
                }
            }
        }

        // Check that the right port does not already have some other
        // upstream connection (unless it is a multiport).
        for (c : reactor.connections) {
            if (c !== connection &&
                connection.rightPort.container === c.rightPort.container &&
                connection.rightPort.variable === c.rightPort.variable &&
                (c.rightPort.variable as Port).arraySpec === null) {
                error(
                    "Cannot connect: Port named '" + c.rightPort.variable.name +
                        "' may only be connected to a single upstream port.",
                    Literals.CONNECTION__RIGHT_PORT)
            }
        }
    }

    @Check(FAST)
    def checkDeadline(Deadline deadline) {
        if (this.target == Targets.C &&
            this.info.overflowingDeadlines.contains(deadline)) {
            error(
                "Deadline exceeds the maximum of " +
                    TimeValue.MAX_LONG_DEADLINE + " nanoseconds.",
                Literals.DEADLINE__DELAY)
        }
    }
    
    @Check(NORMAL)
    def checkBuild(Model model) {
        val uri = model.eResource?.URI
        if (uri !== null && uri.isPlatform) {
            // Running in INTEGRATED mode. Clear marks.
            // This has to be done here rather than in doGenerate()
            // of GeneratorBase because, apparently, doGenerate() is
            // not called at all if there are marks.
            //val uri = model.eResource.URI
            val iResource = ResourcesPlugin.getWorkspace().getRoot().getFile(
                new Path(uri.toPlatformString(true)))
            try {
                // First argument can be null to delete all markers.
                // But will that delete xtext markers too?
                iResource.deleteMarkers(IMarker.PROBLEM, true,
                    IResource.DEPTH_INFINITE);
            } catch (Exception e) {
                // Ignore, but print a warning.
                println("Warning: Deleting markers in the IDE failed: " + e)
            }
        }
    }

    @Check(FAST)
    def checkInput(Input input) {
        checkName(input.name, Literals.VARIABLE__NAME)
        if (allNames.contains(input.name)) {
            error(
                UNIQUENESS_MESSAGE + input.name,
                Literals.VARIABLE__NAME
            )
        }
        inputs.add(input.name)
        allNames.add(input.name)
        if (target.requiresTypes) {
            if (input.type === null) {
                error("Input must have a type.", Literals.TYPED_VARIABLE__TYPE)
            }
        }
        
        // mutable has no meaning in C++
        if (input.mutable && this.target == Targets.CPP) {
            warning(
                "The mutable qualifier has no meaning for the C++ target and should be removed. " +
                "In C++, any value can be made mutable by calling get_mutable_copy().",
                Literals.INPUT__MUTABLE
            )
        }
    }

    @Check(FAST)
    def checkInstantiation(Instantiation instantiation) {
        checkName(instantiation.name, Literals.INSTANTIATION__NAME)
        if (allNames.contains(instantiation.name)) {
            error(
                UNIQUENESS_MESSAGE + instantiation.name,
                Literals.INSTANTIATION__NAME
            )
        }
        allNames.add(instantiation.name)
        if (instantiation.reactorClass.isMain || instantiation.reactorClass.isFederated) {
            error(
                "Cannot instantiate a main (or federated) reactor: " +
                    instantiation.reactorClass.name,
                Literals.INSTANTIATION__REACTOR_CLASS
            )
        }
        
        // Report error if this instantiation is part of a cycle.
        // FIXME: improve error message.
        if (this.info.instantiationGraph.cycles.size > 0) {
            for (cycle : this.info.instantiationGraph.cycles) {
                if (cycle.contains(instantiation.eContainer as Reactor) && cycle.contains(instantiation.reactorClass)) {
                    error(
                        "Instantiation is part of a cycle: " +
                            instantiation.reactorClass.name,
                        Literals.INSTANTIATION__REACTOR_CLASS
                    )
                }
            }
        }
    }

    /** Check target parameters, which are key-value pairs. */
    @Check(FAST)
    def checkKeyValuePair(KeyValuePair param) {
        // Check only if the container's container is a Target.
        if (param.eContainer.eContainer instanceof Target) {

            if (!TargetProperties.isValidName(param.name)) {
                warning(
                    "Unrecognized target parameter: " + param.name +
                        ". Recognized parameters are " +
                        TargetProperties.values().join(", "),
                    Literals.KEY_VALUE_PAIR__NAME)
            }
            val prop = TargetProperties.get(param.name)

            if (!prop.supportedBy.contains(this.target)) {
                warning(
                    "The target parameter: " + param.name +
                        " is not supported by the " + this.target +
                        " and will thus be ignored.",
                    Literals.KEY_VALUE_PAIR__NAME)
            }

            switch prop {
                case BUILD_TYPE:
                    if (!Arrays.asList(BuildTypes.values()).exists [
                        it.toString.equals(param.value.id)
                    ]) {
                        error(
                            "Target property build-type is required to be one of " +
                                BuildTypes.values(),
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                case CMAKE_INCLUDE:
                    if (param.value.literal === null) {
                        error(
                            "Target property cmake-include is required to be a string.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                case COMPILER:
                    if (param.value.literal === null) {
                        error(
                            "Target property compile is required to be a string.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                case COORDINATION:
                    if (param.value.id.isNullOrEmpty || 
                        !(param.value.id.equals("centralized") || 
                        param.value.id.equals("distributed"))) {
                        error("Target property 'coordination' can either be " +
                            "'centralized' or 'distributed'.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    } 
                case FLAGS:
                    if (param.value.literal === null) {
                        error(
                            "Target property flags is required to be a string.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                case FAST:
                    if (!param.value.id.equals('true') &&
                        !param.value.id.equals('false')) {
                        error(
                            "Target property fast is required to be true or false.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                case KEEPALIVE:
                    if (!param.value.id.equals('true') &&
                        !param.value.id.equals('false')) {
                        error(
                            "Target property keepalive is required to be true or false.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                case LOGGING:
                    if (!Arrays.asList(LoggingLevels.values()).exists [
                        it.toString.equals(param.value.id)
                    ]) {
                        error(
                            "Target property logging is required to be one of " +
                                LoggingLevels.values(),
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                case NO_COMPILE:
                    if (!param.value.id.equals('true') &&
                        !param.value.id.equals('false')) {
                        error(
                            "Target property no-compile is required to be true or false.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                case NO_RUNTIME_VALIDATION:
                    if (!param.value.id.equals('true') &&
                        !param.value.id.equals('false')) {
                        error(
                            "Target property no-runtime-validation is required to be true or false.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                case THREADS: {
                    if (param.value.literal === null) {
                        error(
                            "Target property threads is required to be a non-negative integer.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                    try {
                        val value = Integer.decode(param.value.literal)
                        if (value < 0) {
                            error(
                                "Target property threads is required to be a non-negative integer.",
                                Literals.KEY_VALUE_PAIR__VALUE)
                        }
                    } catch (NumberFormatException ex) {
                        error(
                            "Target property threads is required to be a non-negative integer.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
                }
                case TIMEOUT:
                    if (param.value.unit === null) {
                        error(
                            "Target property timeout requires a time unit. Should be one of " +
                                TimeUnit.VALUES.filter[it != TimeUnit.NONE],
                            Literals.KEY_VALUE_PAIR__VALUE)
                    } else if (param.value.time < 0) {
                        error(
                            "Target property timeout requires a non-negative time value with units.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
               case TRACING:
                    if (!param.value.id.equals('true') &&
                        !param.value.id.equals('false')) {
                        error(
                            "Target property tracing is required to be true or false.",
                            Literals.KEY_VALUE_PAIR__VALUE)
                    }
            }
        }
    }

    @Check(FAST)
    def checkOutput(Output output) {
        checkName(output.name, Literals.VARIABLE__NAME)
        if (allNames.contains(output.name)) {
            error(
                UNIQUENESS_MESSAGE + output.name,
                Literals.VARIABLE__NAME
            )
        }
        outputs.add(output.name);
        allNames.add(output.name)
        if (this.target.requiresTypes) {
            if (output.type === null) {
                error("Output must have a type.", Literals.TYPED_VARIABLE__TYPE)
            }
        }
    }

    @Check(NORMAL)
    def checkModel(Model model) {
        info.update(model)
    }

    @Check(FAST)
    def checkParameter(Parameter param) {
        checkName(param.name, Literals.PARAMETER__NAME)
        if (allNames.contains(param.name)) {
            error(
                UNIQUENESS_MESSAGE + param.name,
                Literals.PARAMETER__NAME
            )
        }
        parameters.add(param.name)
        allNames.add(param.name)

        if (param.init.exists[it.parameter !== null]) {
            // Initialization using parameters is forbidden.
            error("Parameter cannot be initialized using parameter.",
                Literals.PARAMETER__INIT)
        }
        
        if (param.init === null || param.init.size == 0) {
            // All parameters must be initialized.
            error("Uninitialized parameter.", Literals.PARAMETER__INIT)
        } else if (param.isOfTimeType) {
             // We do additional checks on types because we can make stronger
             // assumptions about them.
             
             // If the parameter is not a list, cannot be initialized
             // using a one.
             if (param.init.size > 1 && param.type.arraySpec === null) {
                error("Time parameter cannot be initialized using a list.",
                    Literals.PARAMETER__INIT)
            } else {
                // The parameter is a singleton time.
                val init = param.init.get(0)
                if (init.time === null) {
                    if (init !== null && !init.isZero) {
                        if (init.isInteger) {
                            error("Missing time units. Should be one of " +
                                TimeUnit.VALUES.filter [
                                    it != TimeUnit.NONE
                                ], Literals.PARAMETER__INIT)
                        } else {
                            error("Invalid time literal.",
                                Literals.PARAMETER__INIT)
                        }
                    }
                } // If time is not null, we know that a unit is also specified.    
            }
        } else if (this.target.requiresTypes) {
            // Report missing target type.
            if (param.inferredType.isUndefined()) {
                error("Type declaration missing.", Literals.PARAMETER__TYPE)
            }
        }

        if (this.target == Targets.C &&
            this.info.overflowingParameters.contains(param)) {
            error(
                "Time value used to specify a deadline exceeds the maximum of " +
                    TimeValue.MAX_LONG_DEADLINE + " nanoseconds.",
                Literals.PARAMETER__INIT)
        }
    }

    @Check(FAST)
    def checkPreamble(Preamble preamble) {
        if (this.target == Targets.CPP) {
            if (preamble.visibility == Visibility.NONE) {
                error(
                    "Preambles for the C++ target need a visibility qualifier (private or public)!",
                    Literals.PREAMBLE__VISIBILITY
                )
            } else if (preamble.visibility == Visibility.PRIVATE) {
                val container = preamble.eContainer
                if (container !== null && container instanceof Reactor) {
                    val reactor = container as Reactor
                    if (reactor.isGeneric) {
                        warning(
                            "Private preambles in generic reactors are not truly private. " +
                                "Since the generated code is placed in a *_impl.hh file, it will " +
                                "be visible on the public interface. Consider using a public " +
                                "preamble within the reactor or a private preamble on file scope.",
                            Literals.PREAMBLE__VISIBILITY)
                    }
                }
            }
        } else if (preamble.visibility != Visibility.NONE) {
            warning(
                '''The «preamble.visibility» qualifier has no meaning for the «this.target.name» target. It should be removed.''',
                Literals.PREAMBLE__VISIBILITY
            )
        }
    }

	@Check(FAST)
	def checkReaction(Reaction reaction) {
		
		if (reaction.triggers === null || reaction.triggers.size == 0) {
			warning("Reaction has no trigger.", Literals.REACTION__TRIGGERS)
		}
		
		// Report error if this reaction is part of a cycle.
        for (cycle : this.info.reactionGraph.cycles) {
            val reactorName = (reaction.eContainer as Reactor).name
            if (cycle.exists[it.node === reaction]) {
                // Report involved triggers.
                val trigs = new LinkedList()
                reaction.triggers.forEach [ t |
                    (t instanceof VarRef && cycle.exists [ c |
                        c.node === (t as VarRef).variable
                    ]) ? trigs.add((t as VarRef).toText) : {}
                ]
                if (trigs.size > 0) {
                    error('''Reaction triggers involved in cyclic dependency in reactor «reactorName»: «trigs.join(', ')».''',
                        Literals.REACTION__TRIGGERS)
                }
                
                // Report involved sources.
                val sources = new LinkedList()
                reaction.sources.forEach [ t |
                    (cycle.exists [ c | c.node === t.variable]) ? 
                        sources.add(t.toText): {}
                ]
                if (sources.size > 0) {
                    error('''Reaction sources involved in cyclic dependency in reactor «reactorName»: «sources.join(', ')».''',
                        Literals.REACTION__SOURCES)
                }
                
                // Report involved effects.
                val effects = new LinkedList()
                reaction.effects.forEach [ t |
                    (cycle.exists [ c | c.node === t.variable]) ? 
                        effects.add(t.toText): {}
                ]
                if (effects.size > 0) {
                    error('''Reaction effects involved in cyclic dependency in reactor «reactorName»: «effects.join(', ')».''',
                        Literals.REACTION__EFFECTS)
                }
                
                if (trigs.size + sources.size == 0) {
                    error(
                    '''Cyclic dependency due to preceding reaction. Consider reordering reactions within reactor «reactorName» to avoid causality loop.''',
                    Literals.REACTION__CODE
                    )    
                } else if (effects.size == 0) {
                    error(
                    '''Cyclic dependency due to succeeding reaction. Consider reordering reactions within reactor «reactorName» to avoid causality loop.''',
                    Literals.REACTION__CODE
                    )    
                }
                // Not reporting reactions that are part of cycle _only_ due to reaction ordering.
                // Moving them won't help solve the problem.
            }
        }
        // FIXME: improve error message. 
	}

    @Check(FAST)
    def checkReactor(Reactor reactor) {
        checkName(reactor.name, Literals.REACTOR__NAME)
        if (reactorClasses.contains(reactor.name)) {
            error(
                "Names of reactor classes must be unique: " + reactor.name,
                Literals.REACTOR__NAME
            )
        }
        reactorClasses.add(reactor.name);
        
        // C++ reactors may not be called 'preamble'
        if (this.target == Targets.CPP && reactor.name.equalsIgnoreCase("preamble")) {
            error(
                "Reactor cannot be named '" + reactor.name + "'",
                Literals.REACTOR__NAME
            )
        }
        
        if (reactor.host !== null) {
            if (!reactor.isFederated) {
                error(
                    "Cannot assign a host to reactor '" + reactor.name + 
                    "' because it is not federated.",
                    Literals.REACTOR__HOST
                )
            }
        }
        // FIXME: In TypeScript, there are certain classes that a reactor class should not collide with
        // (essentially all the classes that are imported by default).

        var variables = new ArrayList()
        variables.addAll(reactor.inputs)
        variables.addAll(reactor.outputs)
        variables.addAll(reactor.actions)
        variables.addAll(reactor.timers)
                
        // Perform checks on super classes.
        for (superClass : reactor.superClasses ?: emptyList) {
            var conflicts = new HashSet()
            
            // Detect input conflicts
            checkConflict(superClass.inputs, reactor.inputs, variables, conflicts)
            // Detect output conflicts
            checkConflict(superClass.outputs, reactor.outputs, variables, conflicts)
            // Detect output conflicts
            checkConflict(superClass.actions, reactor.actions, variables, conflicts)
            // Detect conflicts
            for (timer : superClass.timers) {
                if (timer.hasNameConflict(variables.filter[it | !reactor.timers.contains(it)])) {
                    conflicts.add(timer)
                } else {
                    variables.add(timer)
                }
            }
            
            // Report conflicts.
            if (conflicts.size > 0) {
                val names = new ArrayList();
                conflicts.forEach[it | names.add(it.name)]
                error(
                '''Cannot extend «superClass.name» due to the following conflicts: «names.join(',')».''',
                Literals.REACTOR__SUPER_CLASSES
                )    
            }
            
            
            // FIXME: other things to check:
            // - 
        }
        
    }
    /** 
     * For each input, report a conflict if:
     *   1) the input exists and the type doesn't match; or
     *   2) the input has a name clash with variable that is not an input.
     * @param superVars List of typed variables of a particular kind (i.e.,
     * inputs, outputs, or actions), found in a super class.
     * @param sameKind Typed variables of the same kind, found in the subclass.
     * @param allOwn Accumulator of non-conflicting variables incorporated in the
     * subclass.
     * @param conflicts Set of variables that are in conflict, to be used by this
     * function to report conflicts.
     */
    def <T extends TypedVariable> checkConflict (EList<T> superVars,
        EList<T> sameKind, List<Variable> allOwn,
        HashSet<Variable> conflicts) {
        for (superVar : superVars) {
                val match = sameKind.findFirst [ it |
                it.name.equals(superVar.name)
            ]
            val rest = allOwn.filter[it|!sameKind.contains(it)]
            if ((match !== null && superVar.type !== match.type) || superVar.hasNameConflict(rest)) {
                conflicts.add(superVar)
            } else {
                allOwn.add(superVar)
            }
        }
    }

    /**
     * Report whether the name of the given element matches any variable in
     * the ones to check against.
     * @param element The element to compare against all variables in the given iterable.
     * @param toCheckAgainst Iterable variables to compare the given element against.
     */
    def boolean hasNameConflict(Variable element,
        Iterable<Variable> toCheckAgainst) {
        if (toCheckAgainst.filter[it|it.name.equals(element.name)].size > 0) {
            return true
        }
        return false
    }

    @Check(FAST)
    def checkHost(Host host) {
        val addr = host.addr
        val user = host.user
        if (user !== null && !user.matches(usernameRegex)) {
            warning(
                "Invalid user name.",
                Literals.HOST__USER
            )
        }
        if (host instanceof IPV4Host && !addr.matches(ipv4Regex)) {
            warning(
                "Invalid IP address.",
                Literals.HOST__ADDR
            )
        } else if (host instanceof IPV6Host && !addr.matches(ipv6Regex)) {
            warning(
                "Invalid IP address.",
                Literals.HOST__ADDR
            )
        } else if (host instanceof NamedHost && !addr.matches(hostOrFQNRegex)) {
            warning(
                "Invalid host name or fully qualified domain name.",
                Literals.HOST__ADDR
            )
        }
    }

    @Check(FAST)
    def checkState(StateVar stateVar) {
        checkName(stateVar.name, Literals.STATE_VAR__NAME)
        if (allNames.contains(stateVar.name)) {
            error(
                UNIQUENESS_MESSAGE + stateVar.name,
                Literals.STATE_VAR__NAME
            )
        }
        inputs.add(stateVar.name);
        allNames.add(stateVar.name)

        if (stateVar.isOfTimeType) {
            // If the state is declared to be a time,
            // make sure that it is initialized correctly.
            if (stateVar.init !== null) {
                for (init : stateVar.init) {
                    if (stateVar.type !== null && stateVar.type.isTime &&
                        !init.isValidTime) {
                        if (stateVar.isParameterized) {
                            error(
                                "Referenced parameter does not denote a time.",
                                Literals.STATE_VAR__INIT)
                        } else {
                            if (init !== null && !init.isZero) {
                                if (init.isInteger) {
                                    error(
                                        "Missing time units. Should be one of " +
                                            TimeUnit.VALUES.filter [
                                                it != TimeUnit.NONE
                                            ], Literals.STATE_VAR__INIT)
                                } else {
                                    error("Invalid time literal.",
                                        Literals.STATE_VAR__INIT)
                                }
                            }
                        }
                    }
                }
            }
        } else if (this.target.requiresTypes && stateVar.inferredType.isUndefined) {
            // Report if a type is missing
            error("State must have a type.", Literals.STATE_VAR__TYPE)
        }

        if (this.target == Targets.C && stateVar.init.size > 1) {
            // In C, if initialization is done with a list, elements cannot
            // refer to parameters.
            if (stateVar.init.exists[it.parameter !== null]) {
                error("List items cannot refer to a parameter.",
                    Literals.STATE_VAR__INIT)
            }
        }

    }

    @Check(FAST)
    def checkTarget(Target target) {
        if (!Targets.isValidName(target.name)) {
            warning("Unrecognized target: " + target.name,
                Literals.TARGET__NAME)
        } else {
            this.target = Targets.get(target.name);
        }
    }

    @Check(FAST)
    def checkValueAsTime(Value value) {
        val container = value.eContainer

        if (container instanceof Timer || container instanceof Action ||
            container instanceof Connection || container instanceof Deadline) {

            // If parameter is referenced, check that it is of the correct type.
            if (value.parameter !== null) {
                if (!value.parameter.isOfTimeType) {
                    error("Parameter is not of time type",
                        Literals.VALUE__PARAMETER)
                }
            } else if (value.time === null) {
                if (value.literal !== null && !value.literal.isZero) {
                    if (value.literal.isInteger) {
                            error("Missing time units. Should be one of " +
                                TimeUnit.VALUES.filter [
                                    it != TimeUnit.NONE
                                ], Literals.VALUE__LITERAL)
                        } else {
                            error("Invalid time literal.",
                                Literals.VALUE__LITERAL)
                        }
                } else if (value.code !== null && !value.code.isZero) {
                    if (value.code.isInteger) {
                            error("Missing time units. Should be one of " +
                                TimeUnit.VALUES.filter [
                                    it != TimeUnit.NONE
                                ], Literals.VALUE__CODE)
                        } else {
                            error("Invalid time literal.",
                                Literals.VALUE__CODE)
                        }
                }
            }
        }
    }
    
    @Check(FAST)
    def checkTimer(Timer timer) {
        checkName(timer.name, Literals.VARIABLE__NAME)
        if (allNames.contains(timer.name)) {
            error(
                UNIQUENESS_MESSAGE + timer.name,
                Literals.VARIABLE__NAME
            )
        }
        timers.add(timer.name);
        allNames.add(timer.name)
    }
    
    @Check(FAST)
    def checkType(Type type) {
        // FIXME: disallow the use of generics in C
        if (this.target == Targets.CPP) {
            if (type.stars.size > 0) {
                warning(
                    "Raw pointers should be avoided in conjunction with LF. Ports " +
                    "and actions implicitly use smart pointers. In this case, " +
                    "the pointer here is likely not needed. For parameters and state " +
                    "smart pointers should be used explicitly if pointer semantics " +
                    "are really needed.",
                    Literals.TYPE__STARS
                )
            }
        }
    }

    static val UNIQUENESS_MESSAGE = "Names of contained objects (inputs, outputs, actions, timers, parameters, state, and reactors) must be unique: "
    static val UNDERSCORE_MESSAGE = "Names of objects (inputs, outputs, actions, timers, parameters, state, reactor definitions, and reactor instantiation) may not start with \"__\": "
    static val ACTIONS_MESSAGE = "\"actions\" is a reserved word for the TypeScript target for objects (inputs, outputs, actions, timers, parameters, state, reactor definitions, and reactor instantiation): "
    static val RESERVED_MESSAGE = "Reserved words in the target language are not allowed for objects (inputs, outputs, actions, timers, parameters, state, reactor definitions, and reactor instantiation): "

}
